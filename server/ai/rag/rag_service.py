import hashlib
import json
from math import sqrt
from pathlib import Path

from sklearn.feature_extraction.text import HashingVectorizer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from server.config import get_settings
from server.models import Course, Paper, RagChunk, RagDocument


EMBEDDING_KEY = "_embedding"
EMBEDDING_VERSION_KEY = "_embeddingVersion"
EMBEDDING_VERSION = "hashing-char-2-4-512-v1"
EMBEDDING_FEATURES = 512
MMR_LAMBDA = 0.75


class RAGService:
    _vectorizer = HashingVectorizer(
        analyzer="char",
        ngram_range=(2, 4),
        n_features=EMBEDDING_FEATURES,
        alternate_sign=False,
        norm="l2",
    )

    def __init__(self, db: AsyncSession):
        self.db = db

    @staticmethod
    def _hash(content: str) -> str:
        return hashlib.sha256(content.encode("utf-8")).hexdigest()

    @staticmethod
    def _split(content: str, size: int = 420, overlap: int = 60) -> list[str]:
        normalized = "\n".join(line.strip() for line in content.splitlines() if line.strip())
        if not normalized:
            return []
        chunks: list[str] = []
        start = 0
        while start < len(normalized):
            end = min(len(normalized), start + size)
            chunks.append(normalized[start:end])
            if end == len(normalized):
                break
            start = max(start + 1, end - overlap)
        return chunks

    @classmethod
    def _vectorize(cls, content: str) -> dict[int, float]:
        if not content.strip():
            return {}
        row = cls._vectorizer.transform([content]).tocsr()
        return {
            int(index): round(float(value), 8)
            for index, value in zip(row.indices, row.data)
            if value
        }

    @staticmethod
    def _encode_vector(vector: dict[int, float]) -> dict[str, float]:
        return {str(index): value for index, value in vector.items()}

    @staticmethod
    def _decode_vector(raw_vector: object) -> dict[int, float]:
        if not isinstance(raw_vector, dict):
            return {}
        vector: dict[int, float] = {}
        for raw_index, raw_value in raw_vector.items():
            try:
                index = int(raw_index)
                value = float(raw_value)
            except (TypeError, ValueError):
                continue
            if 0 <= index < EMBEDDING_FEATURES and value:
                vector[index] = value
        return vector

    @classmethod
    def _chunk_metadata(cls, metadata: dict, content: str) -> dict:
        return {
            **metadata,
            EMBEDDING_VERSION_KEY: EMBEDDING_VERSION,
            EMBEDDING_KEY: cls._encode_vector(cls._vectorize(content)),
        }

    @classmethod
    def _chunk_vector(cls, chunk: RagChunk) -> dict[int, float]:
        metadata = chunk.metadata_json or {}
        if metadata.get(EMBEDDING_VERSION_KEY) == EMBEDDING_VERSION:
            stored = cls._decode_vector(metadata.get(EMBEDDING_KEY))
            if stored:
                return stored
        # 兼容尚未执行知识库重建的旧分块；只在本次检索中临时计算，不修改业务数据。
        return cls._vectorize(chunk.content)

    @staticmethod
    def _cosine(left: dict[int, float], right: dict[int, float]) -> float:
        if not left or not right:
            return 0.0
        smaller, larger = (left, right) if len(left) <= len(right) else (right, left)
        dot = sum(value * larger.get(index, 0.0) for index, value in smaller.items())
        if dot <= 0:
            return 0.0
        left_norm = sqrt(sum(value * value for value in left.values()))
        right_norm = sqrt(sum(value * value for value in right.values()))
        if not left_norm or not right_norm:
            return 0.0
        return dot / (left_norm * right_norm)

    @classmethod
    def _mmr_indices(
        cls,
        relevance_scores: list[float],
        vectors: list[dict[int, float]],
        limit: int,
    ) -> list[int]:
        candidates = [
            index
            for index, score in sorted(enumerate(relevance_scores), key=lambda item: item[1], reverse=True)
            if score > 0
        ]
        selected: list[int] = []
        while candidates and len(selected) < limit:
            if not selected:
                best = candidates[0]
            else:
                def mmr_key(index: int) -> tuple[float, float, int]:
                    redundancy = max(cls._cosine(vectors[index], vectors[item]) for item in selected)
                    mmr_score = MMR_LAMBDA * relevance_scores[index] - (1 - MMR_LAMBDA) * redundancy
                    return mmr_score, relevance_scores[index], -index

                best = max(candidates, key=mmr_key)
            selected.append(best)
            candidates.remove(best)
        return selected

    async def _upsert_document(self, source_type: str, source_id: str, title: str, content: str, metadata: dict) -> tuple[int, bool]:
        content_hash = self._hash(content)
        current = await self.db.scalar(select(RagDocument).where(
            RagDocument.source_type == source_type,
            RagDocument.source_id == source_id,
            RagDocument.content_hash == content_hash,
        ))
        if current:
            current.title = title
            current.metadata_json = dict(metadata)
            chunks = list((await self.db.scalars(select(RagChunk).where(
                RagChunk.document_id == current.id
            ))).all())
            for chunk in chunks:
                chunk.metadata_json = self._chunk_metadata(metadata, chunk.content)
            return current.id, False
        old_rows = list((await self.db.scalars(select(RagDocument).where(
            RagDocument.source_type == source_type,
            RagDocument.source_id == source_id,
        ))).all())
        for old in old_rows:
            await self.db.delete(old)
        row = RagDocument(
            source_type=source_type,
            source_id=source_id,
            title=title,
            content=content,
            content_hash=content_hash,
            metadata_json=metadata,
        )
        self.db.add(row)
        await self.db.flush()
        for index, chunk in enumerate(self._split(content)):
            self.db.add(RagChunk(
                document_id=row.id,
                chunk_index=index,
                content=chunk,
                metadata_json=self._chunk_metadata(metadata, chunk),
            ))
        return row.id, True

    async def rebuild(self) -> dict:
        added = 0
        courses = list((await self.db.scalars(select(Course).where(Course.is_active.is_(True)))).all())
        for row in courses:
            content = (
                f"课程名称：{row.name}\n年级：{row.grade}\n学科：{row.subject}\n课程等级：{row.level}\n"
                f"难度：{row.difficulty}\n知识点：{'、'.join(row.knowledge_points or [])}\n"
                f"适合人群：{row.suitable_for}\n课程介绍：{row.description}\n价格：{float(row.price):.2f}元"
            )
            _id, created = await self._upsert_document("course", str(row.id), row.name, content, {
                "courseId": row.id,
                "grade": row.grade,
                "subject": row.subject,
                "level": row.level,
                "difficulty": row.difficulty,
                "knowledgePoints": row.knowledge_points or [],
            })
            added += int(created)
        papers = list((await self.db.scalars(select(Paper).where(Paper.is_active.is_(True)))).all())
        for row in papers:
            content = (
                f"试卷名称：{row.name}\n年级：{row.grade}\n学科：{row.subject}\n难度：{row.difficulty}\n"
                f"知识点：{'、'.join(row.knowledge_points or [])}\n题目数量：{row.question_count}"
            )
            _id, created = await self._upsert_document("paper", str(row.id), row.name, content, {
                "paperId": row.id,
                "grade": row.grade,
                "subject": row.subject,
                "difficulty": row.difficulty,
                "level": row.suitable_course_level,
                "knowledgePoints": row.knowledge_points or [],
            })
            added += int(created)
        knowledge_dir = Path(__file__).resolve().parents[2] / "knowledge"
        if knowledge_dir.exists():
            for path in sorted(knowledge_dir.glob("*")):
                if path.suffix.lower() not in {".md", ".json"}:
                    continue
                text = path.read_text(encoding="utf-8")
                if path.suffix.lower() == ".json":
                    text = json.dumps(json.loads(text), ensure_ascii=False, indent=2)
                _id, created = await self._upsert_document("knowledge", path.name, path.stem, text, {"file": path.name})
                added += int(created)
        await self.db.flush()
        total = len(list((await self.db.scalars(select(RagDocument.id))).all()))
        chunks = len(list((await self.db.scalars(select(RagChunk.id))).all()))
        return {"documents": total, "chunks": chunks, "added": added}

    async def search(
        self,
        query: str,
        top_k: int | None = None,
        *,
        grade: str | None = None,
        subject: str | None = None,
        source_types: list[str] | None = None,
    ) -> list[dict]:
        raw_rows = (await self.db.execute(
            select(RagChunk, RagDocument).join(RagDocument, RagDocument.id == RagChunk.document_id)
        )).all()
        if not raw_rows or not query.strip():
            return []
        allowed_sources = set(source_types or [])
        rows = []
        for chunk, document in raw_rows:
            metadata = document.metadata_json or {}
            if allowed_sources and document.source_type not in allowed_sources:
                continue
            if grade:
                stored_grade = metadata.get("grade")
                if stored_grade and stored_grade != grade:
                    continue
                if not stored_grade and document.source_type in {"course", "paper"} and f"年级：{grade}" not in document.content:
                    continue
            if subject:
                stored_subject = metadata.get("subject")
                if stored_subject and stored_subject != subject:
                    continue
                if not stored_subject and document.source_type in {"course", "paper"} and f"学科：{subject}" not in document.content:
                    continue
            rows.append((chunk, document))
        if not rows:
            return []
        query_vector = self._vectorize(query)
        vectors = [self._chunk_vector(chunk) for chunk, _document in rows]
        scores = [self._cosine(query_vector, vector) for vector in vectors]
        limit = max(1, min(int(top_k or get_settings().rag_top_k), 6))
        ranked = self._mmr_indices(scores, vectors, limit)
        result: list[dict] = []
        for index in ranked:
            score = scores[index]
            chunk, document = rows[index]
            result.append({
                "title": document.title,
                "sourceType": document.source_type,
                "sourceId": document.source_id,
                "content": chunk.content,
                "score": round(float(score), 4),
                "metadata": document.metadata_json,
            })
        return result

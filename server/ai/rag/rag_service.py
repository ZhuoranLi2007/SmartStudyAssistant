import hashlib
import json
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from server.config import get_settings
from server.models import Course, Paper, RagChunk, RagDocument


class RAGService:
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

    async def _upsert_document(self, source_type: str, source_id: str, title: str, content: str, metadata: dict) -> tuple[int, bool]:
        content_hash = self._hash(content)
        current = await self.db.scalar(select(RagDocument).where(
            RagDocument.source_type == source_type,
            RagDocument.source_id == source_id,
            RagDocument.content_hash == content_hash,
        ))
        if current:
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
            self.db.add(RagChunk(document_id=row.id, chunk_index=index, content=chunk, metadata_json=metadata))
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
            _id, created = await self._upsert_document("course", str(row.id), row.name, content, {"courseId": row.id})
            added += int(created)
        papers = list((await self.db.scalars(select(Paper).where(Paper.is_active.is_(True)))).all())
        for row in papers:
            content = (
                f"试卷名称：{row.name}\n年级：{row.grade}\n学科：{row.subject}\n难度：{row.difficulty}\n"
                f"知识点：{'、'.join(row.knowledge_points or [])}\n题目数量：{row.question_count}"
            )
            _id, created = await self._upsert_document("paper", str(row.id), row.name, content, {"paperId": row.id})
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

    async def search(self, query: str, top_k: int | None = None) -> list[dict]:
        rows = (await self.db.execute(
            select(RagChunk, RagDocument).join(RagDocument, RagDocument.id == RagChunk.document_id)
        )).all()
        if not rows or not query.strip():
            return []
        texts = [chunk.content for chunk, _document in rows]
        scores: list[float]
        try:
            from sklearn.feature_extraction.text import TfidfVectorizer
            from sklearn.metrics.pairwise import cosine_similarity

            matrix = TfidfVectorizer(analyzer="char", ngram_range=(2, 4), min_df=1).fit_transform(texts + [query])
            scores = cosine_similarity(matrix[-1], matrix[:-1]).ravel().tolist()
        except (ImportError, ValueError):
            query_chars = set(query)
            scores = [len(query_chars.intersection(set(text))) / max(len(query_chars), 1) for text in texts]
        limit = top_k or get_settings().rag_top_k
        ranked = sorted(enumerate(scores), key=lambda item: item[1], reverse=True)
        result: list[dict] = []
        for index, score in ranked[:limit]:
            if score <= 0:
                continue
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

import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from server.database import Base, engine
from server.main import app


@pytest_asyncio.fixture
async def client():
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.drop_all)
    async with app.router.lifespan_context(app):
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as test_client:
            yield test_client

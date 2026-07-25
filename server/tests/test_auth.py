import uuid

import pytest

from server.main import app


@pytest.mark.asyncio
async def test_login_errors_and_account_survives_lifespan_restart(client):
    suffix = uuid.uuid4().hex[:8]
    username = f"login_{suffix}"
    password = "secret123"
    payload = {
        "username": username,
        "phone": f"137{suffix[:8]}",
        "password": password,
        "role": "parent",
    }

    register_response = await client.post("/api/auth/register", json=payload)
    assert register_response.status_code == 200, register_response.text

    login_response = await client.post(
        "/api/auth/login",
        json={"account": username, "password": password},
    )
    assert login_response.status_code == 200, login_response.text
    assert login_response.json()["data"]["user"]["username"] == username
    assert login_response.json()["data"]["accessToken"]

    wrong_password_response = await client.post(
        "/api/auth/login",
        json={"account": username, "password": "wrong-password"},
    )
    assert wrong_password_response.status_code == 401
    assert wrong_password_response.json()["message"] == "账号或密码错误"

    async with app.router.lifespan_context(app):
        pass

    login_after_restart = await client.post(
        "/api/auth/login",
        json={"account": username, "password": password},
    )
    assert login_after_restart.status_code == 200, login_after_restart.text

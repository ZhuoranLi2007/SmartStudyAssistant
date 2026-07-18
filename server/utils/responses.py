from uuid import uuid4


def ok(data=None, message: str = "success") -> dict:
    return {"code": 0, "message": message, "data": data, "requestId": str(uuid4())}

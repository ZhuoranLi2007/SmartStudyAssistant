from server.ai.intent import classify_by_rules, extract_entities


def classify_intent(message: str) -> str:
    return classify_by_rules(message).intent.value


def extract_fields(message: str, context: dict) -> dict:
    entities = extract_entities(message, context)
    if "weakPoints" in entities:
        entities["weak_points"] = entities["weakPoints"]
    if "learningGoal" in entities:
        entities["learning_goal"] = entities["learningGoal"]
    return entities

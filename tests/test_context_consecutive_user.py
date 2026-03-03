"""Tests that build_messages() never produces consecutive same-role messages."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from nanobot.agent.context import ContextBuilder


def _make_workspace(tmp_path: Path) -> Path:
    workspace = tmp_path / "workspace"
    workspace.mkdir(parents=True)
    return workspace


def _has_consecutive_same_role(messages: list[dict[str, Any]]) -> bool:
    """Return True if any two adjacent messages share the same role."""
    for i in range(1, len(messages)):
        if messages[i]["role"] == messages[i - 1]["role"]:
            return True
    return False


class TestNoConsecutiveSameRole:
    """build_messages() must never return consecutive messages with the same role."""

    def test_empty_history(self, tmp_path: Path) -> None:
        builder = ContextBuilder(_make_workspace(tmp_path))
        messages = builder.build_messages(
            history=[],
            current_message="hello",
            channel="cli",
            chat_id="direct",
        )
        assert not _has_consecutive_same_role(messages)

    def test_history_ending_with_assistant(self, tmp_path: Path) -> None:
        builder = ContextBuilder(_make_workspace(tmp_path))
        history = [
            {"role": "user", "content": "first"},
            {"role": "assistant", "content": "response"},
        ]
        messages = builder.build_messages(
            history=history,
            current_message="second",
            channel="telegram",
            chat_id="123",
        )
        assert not _has_consecutive_same_role(messages)

    def test_history_ending_with_user(self, tmp_path: Path) -> None:
        """Even if history ends with a user message, no consecutive duplication."""
        builder = ContextBuilder(_make_workspace(tmp_path))
        history = [
            {"role": "user", "content": "unanswered question"},
        ]
        messages = builder.build_messages(
            history=history,
            current_message="follow-up",
            channel="discord",
            chat_id="456",
        )
        assert not _has_consecutive_same_role(messages)

    def test_no_channel_info(self, tmp_path: Path) -> None:
        """Works when channel and chat_id are None."""
        builder = ContextBuilder(_make_workspace(tmp_path))
        messages = builder.build_messages(
            history=[],
            current_message="hello",
        )
        assert not _has_consecutive_same_role(messages)


class TestRuntimeContextPreserved:
    """Runtime context metadata must still appear in the final user message."""

    def test_runtime_context_in_merged_message(self, tmp_path: Path) -> None:
        builder = ContextBuilder(_make_workspace(tmp_path))
        messages = builder.build_messages(
            history=[],
            current_message="hello",
            channel="cli",
            chat_id="direct",
        )
        last_user = [m for m in messages if m["role"] == "user"][-1]
        content = last_user["content"]
        assert isinstance(content, str)
        assert ContextBuilder._RUNTIME_CONTEXT_TAG in content
        assert "Current Time:" in content
        assert "Channel: cli" in content
        assert "hello" in content

    def test_user_content_in_merged_message(self, tmp_path: Path) -> None:
        builder = ContextBuilder(_make_workspace(tmp_path))
        messages = builder.build_messages(
            history=[],
            current_message="Return exactly: OK",
            channel="cli",
            chat_id="direct",
        )
        last_user = [m for m in messages if m["role"] == "user"][-1]
        content = last_user["content"]
        assert isinstance(content, str)
        assert "Return exactly: OK" in content


class TestMultimodalMerge:
    """Multimodal messages (with images) must merge correctly."""

    def test_multimodal_prepends_runtime_context_as_text(self, tmp_path: Path) -> None:
        workspace = _make_workspace(tmp_path)
        builder = ContextBuilder(workspace)

        # Create a small valid PNG file
        img_path = tmp_path / "test.png"
        # Minimal 1x1 PNG
        import base64
        png_data = base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4"
            "nGNgYPgPAAEDAQAIicLsAAAABJRU5ErkJggg=="
        )
        img_path.write_bytes(png_data)

        messages = builder.build_messages(
            history=[],
            current_message="describe this image",
            media=[str(img_path)],
            channel="telegram",
            chat_id="789",
        )
        assert not _has_consecutive_same_role(messages)

        last_user = [m for m in messages if m["role"] == "user"][-1]
        content = last_user["content"]
        # Multimodal content is a list
        assert isinstance(content, list)
        # Must contain runtime context as a text block
        text_blocks = [b for b in content if isinstance(b, dict) and b.get("type") == "text"]
        all_text = " ".join(b.get("text", "") for b in text_blocks)
        assert ContextBuilder._RUNTIME_CONTEXT_TAG in all_text
        assert "describe this image" in all_text
        # Must still contain the image
        image_blocks = [b for b in content if isinstance(b, dict) and b.get("type") == "image_url"]
        assert len(image_blocks) == 1

    def test_multimodal_no_valid_images_falls_back_to_string(self, tmp_path: Path) -> None:
        """When media paths don't resolve to valid images, content stays as string."""
        workspace = _make_workspace(tmp_path)
        builder = ContextBuilder(workspace)

        messages = builder.build_messages(
            history=[],
            current_message="hello",
            media=["/nonexistent/image.png"],
            channel="cli",
            chat_id="direct",
        )
        assert not _has_consecutive_same_role(messages)

        last_user = [m for m in messages if m["role"] == "user"][-1]
        assert isinstance(last_user["content"], str)

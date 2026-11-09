"""Download the recommended IR files. Not used during inference."""
import argparse
from pathlib import Path
from huggingface_hub import snapshot_download


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision", default="main")
    args = parser.parse_args()
    snapshot_download(
        repo_id="OpenVINO/Qwen2.5-1.5B-Instruct-int4-ov",
        revision=args.revision,
        token=False,
        local_dir=str(args.output.resolve()),
        allow_patterns=["*.xml", "*.bin", "*.json", "*.txt", "*.model", "*.jinja"],
    )
    print("Model directory:", args.output.resolve())


if __name__ == "__main__":
    main()

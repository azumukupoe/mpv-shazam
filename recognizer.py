import sys
import json
import asyncio
import traceback
from shazamio import Shazam

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

async def recognize_song(file_path):
    try:
        shazam = Shazam()
        out = await shazam.recognize(file_path)

        if "track" in out:
            track = out["track"]

            metadata = {
                "title": track.get("title", "Unknown Title"),
                "artist": track.get("subtitle", "Unknown Artist"),
                "album": "Unknown Album",
                "year": "Unknown Year",
                "genre": track.get("genres", {}).get("primary", "Unknown Genre"),
                "label": "Unknown Label",
                "cover": track.get("images", {}).get("coverart", "No Cover"),
                "link": track.get("url", "")
            }

            for section in track.get("sections", []):
                if section.get("type") == "SONG":
                    for meta in section.get("metadata", []):
                        if meta.get("title") == "Album":
                            metadata["album"] = meta.get("text", "Unknown Album")
                        if meta.get("title") == "Label":
                            metadata["label"] = meta.get("text", "Unknown Label")
                        if meta.get("title") == "Released":
                            metadata["year"] = meta.get("text", "Unknown Year")

            print(json.dumps(metadata))
        else:
            print(json.dumps({"error": "No song recognized"}))
    except Exception as e:
        print(json.dumps({"error": str(e), "detail": traceback.format_exc()}))

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No audio file provided"}))
        sys.exit(1)
    
    audio_file = sys.argv[1]
    asyncio.run(recognize_song(audio_file))
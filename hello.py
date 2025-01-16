from cryptography.fernet import Fernet
from pathlib import Path


def main():
    key = Path("key.txt").read_bytes()
    encrypted_message = Path("message.txt").read_bytes()

    fernet = Fernet(key)
    print(fernet.decrypt(encrypted_message).decode())


if __name__ == "__main__":
    main()

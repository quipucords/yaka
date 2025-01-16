# Yet Another Konflux Attempt

This is a playground to prototype, reproduce issues in a smaller scale (and attempt to solve them)
in a more controlled environment.


# Generating the lockfiles

```
uv export -o requirements.txt
uv run pybuild-deps compile --output-file=requirements-build.txt
```

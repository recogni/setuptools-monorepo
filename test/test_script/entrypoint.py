import setuptools


def entrypoint(dist: setuptools.dist.Distribution, value1: int, value2: str):
    dist.metadata.description = f"value1={value1} value2={value2}"

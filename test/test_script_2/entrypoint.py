import setuptools


def entrypoint(dist: setuptools.dist.Distribution):
    dist.metadata.author = f"test-author"

import setuptools
import os
import pathlib


def entrypoint(dist: setuptools.dist.Distribution, value1: int, value2: str):
    parent = pathlib.Path(__file__).parent.resolve()

    with open(os.path.join(parent, 'entrypoint_call.txt'), 'w') as file:
        file.write(f'value1={value1} value2={value2}\n')

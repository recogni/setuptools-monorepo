import glob
import os

from setuptools import setup

if __name__ == '__main__':
    tox_dist_dir = os.environ.get('TOX_DISTDIR')
    package_zip = glob.glob(f'{tox_dist_dir}/setuptools-monorepo-*.zip')

    setup(
        monorepo_call={
            'target': 'test_script',
            'args': {
                'value1': 1,
                'value2': 'some',
            },
        },
        setup_requires=['setuptools-monorepo @ file://' + package_zip[0]],
    )

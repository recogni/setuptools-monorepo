Suppress pip upgrade warning to avoid test results breaking

  $ export PIP_DISABLE_PIP_VERSION_CHECK=1

`tox` installs the package by default. We could use skip_install option,
but then the sdist would also be skipped. So we let tox install the package
and then uninstall it manually below

  $ pip3 uninstall --yes --quiet setuptools-monorepo > /dev/null 2>&1

Create the monorepo and copy packages there

  $ mkdir -p monorepo
  $ cd monorepo
  $ git init --quiet

  $ cp -R "${TESTDIR}/test_package" .
  $ cp -R "${TESTDIR}/test_package_2" .
  $ cp -R "${TESTDIR}/test_package_3" .

  $ export SM_MONOREPO_PACKAGE=$(find "${TOX_DISTDIR}" -type f -name "setuptools-monorepo-*.tar.gz" -print | head -n 1 | tr -d '\n')
  $ envsubst < test_package_3/pyproject.toml.envsubst > test_package_3/pyproject.toml

  $ cp -R "${TESTDIR}/test_script" .
  $ cp -R "${TESTDIR}/test_script_2" .

  $ git add test_package test_package_2 test_package_3 test_script test_script_2
  $ git -c user.name='test' -c user.email='test' commit --quiet --message 'test'

Install the package. This will trigger the test_script via setup() keywords. Try several installation methods:

1) relative path
2) with git:// URL
3) with file:// URL

  $ pip3 install --quiet ./test_package
  $ pip3 show test-package | grep '^Summary:'
  Summary: value1=1 value2=some
  $ pip3 uninstall --quiet --yes test-package

  $ pip3 install --quiet "test-package @ git+file://localhost$(realpath .)#subdirectory=test_package"
  $ pip3 uninstall --quiet --yes test-package

  $ pip3 install --quiet "test-package @ file://localhost$(realpath .)#subdirectory=test_package"
  $ pip3 uninstall --quiet --yes test-package

Test other features: multiple scripts, no arguments:

  $ pip3 install --quiet ./test_package_2
  $ pip3 show test-package-2 | grep -E '(^Summary:|^Author:)'
  Summary: value1=1 value2=some
  Author: test-author
  $ pip3 uninstall --quiet --yes test-package-2

Test a package that uses pyproject.toml, and therefore a different entrypoint
for monorepo scripts:

  $ pip3 install --quiet ./test_package_3
  $ pip3 show test-package-3 | grep -E '^Summary:'
  Summary: value1=999 value2=foo

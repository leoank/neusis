{
  lib,
  buildPythonPackage,
  setuptools,
  setuptools-scm,
  numpy,
}:
buildPythonPackage {
  pname = "your_package";
  version = "0.1.0";
  pyproject = true;

  src = ./../../.;

  buildInputs = [
    setuptools
    setuptools-scm
  ];

  propagatedBuildInputs = [
    numpy
  ];
  pythonImportsCheck = [ "your_package" ];

  meta = {
    description = "your_package";
    homepage = "https://github.com/you/your_package";
    license = lib.licenses.mit;
  };

}

from distutils.core import setup
from Cython.Build import cythonize

setup(
    name="cystructs",
    ext_modules=cythonize("src/*.pyx", annotate=True,language_level="3"),
)

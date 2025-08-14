from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="clify",
    version="1.0.0",
    author="ltanedo",
    author_email="lloydtan@buffalo.edu",
    description="Turn any Python module into a CLI with automatic argument parsing and type safety",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/ltanedo/clify-py",
    py_modules=["clify"],  # Single module instead of packages
    packages=find_packages(),  # This will still find the ezenviron package
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: System :: Shells",
        "Topic :: Utilities",
    ],
    python_requires=">=3.6",
    install_requires=[
        # No external dependencies - uses only standard library
    ],
    keywords="cli, command-line, argparse, automation, developer-tools",
    project_urls={
        "Bug Reports": "https://github.com/ltanedo/clify-py/issues",
        "Source": "https://github.com/ltanedo/clify-py",
        "Documentation": "https://github.com/ltanedo/clify-py#readme",
    },
)

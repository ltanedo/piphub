from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(    name="piphub",
    version="1.1.0",
    author="Luis Tanedo",
    author_email="lloydtan@buffalo.edu",
    description="Python package release automation tool for GitHub",
    url="https://github.com/ltanedo/piphub",
    license="MIT",
    long_description_content_type="text/markdown",
    python_requires=">=3.7",
    entry_points={"console_scripts": ["piphub=piphub.__main__:main"]},
    install_requires=[],
    keywords=["github", "release", "automation", "python", "packaging", "ci-cd", "deployment"],
    classifiers=["Development Status :: 4 - Beta", "Intended Audience :: Developers", "License :: OSI Approved :: MIT License", "Operating System :: OS Independent", "Programming Language :: Python :: 3", "Programming Language :: Python :: 3.7", "Programming Language :: Python :: 3.8", "Programming Language :: Python :: 3.9", "Programming Language :: Python :: 3.10", "Programming Language :: Python :: 3.11", "Programming Language :: Python :: 3.12", "Topic :: Software Development :: Build Tools", "Topic :: Software Development :: Libraries :: Python Modules", "Topic :: System :: Software Distribution"],
    project_urls={"Bug Reports": "https://github.com/ltanedo/piphub/issues", "Source": "https://github.com/ltanedo/piphub", "Documentation": "https://github.com/ltanedo/piphub#readme"},
    long_description=long_description,
    packages=find_packages(),
)


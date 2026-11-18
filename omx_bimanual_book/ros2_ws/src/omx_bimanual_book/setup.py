from glob import glob
from setuptools import find_packages, setup


package_name = "omx_bimanual_book"

setup(
    name=package_name,
    version="0.1.0",
    packages=find_packages(exclude=["test"]),
    data_files=[
        ("share/ament_index/resource_index/packages", [f"resource/{package_name}"]),
        (f"share/{package_name}", ["package.xml"]),
        (f"share/{package_name}/launch", glob("launch/*.launch.py")),
        (f"share/{package_name}/config", glob("config/*.yaml")),
    ],
    install_requires=["setuptools"],
    zip_safe=True,
    maintainer="soju",
    maintainer_email="soju@localhost",
    description="Isolated namespaced bringup for bimanual OMX book manipulation.",
    license="Apache-2.0",
)


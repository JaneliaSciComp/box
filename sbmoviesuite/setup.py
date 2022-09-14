"""

installation specs for sbmovie suite

requires setuptools, not just distutils


djo, 5/08

"""

from setuptools import setup

from sbmovielib.version import __version__


setup(name='sbmoviesuite',
    version=__version__,
    description='sbfmf conversion and preview',
    author='Donald J. Olbris, HHMI',
    author_email='olbrisd@janelia.hhmi.org',
    url='http://wiki.int.janelia.org/wiki/display/flyolympiad/Fly+movie+formats',
    packages=['sbmovielib'],
    py_modules = ['sbcompare', 'sbconvert', 'sbinfo', 'sbview1', 'sbview4'],
    install_requires=[ 'numpy>=1.0.3', 'scipy', 'PIL>=1.1.6'],
    license='GPLv2',
    package_data={'':['LICENSE']},
    entry_points = {'console_scripts': [
        'sbcompare=sbcompare:main',
        'sbconvert=sbconvert:main',
        'sbinfo=sbinfo:main',
        'sbview1=sbview1:main',
        'sbview4=sbview4:main'
        ]},
    )


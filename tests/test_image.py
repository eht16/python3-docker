
import subprocess
import unittest

IMAGE_NAME = 'python3-docker-unittest:latest'


class PythonDockerImageTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        # find Python and Pip version in Dockerfile
        cls._python_version = None
        cls._pip_version = None
        with open('Dockerfile') as docker_file:
            for line in docker_file:
                if line.startswith('ENV PYTHON_VERSION='):
                    cls._python_version = line.split('=')[1].strip()
                elif line.startswith('ENV PYTHON_PIP_VERSION='):
                    cls._pip_version = line.split('=')[1].strip()

    def _run_command_in_image(self, *command, code=None):
        input_ = code.encode('utf-8') if code is not None else None
        docker_command = ('docker', 'run', '--rm', '--interactive', IMAGE_NAME) + command
        process = subprocess.run(
            docker_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, input=input_)
        return process.stdout.decode('utf-8').strip()

    def _run_python_in_image(self, code):
        input_ = code.encode('utf-8')
        docker_command = ['docker', 'run', '--rm', '--interactive', IMAGE_NAME]
        process = subprocess.run(
            docker_command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, input=input_)
        return process.stdout.decode('utf-8').strip()

    def test_python_version_command_line(self):
        result = self._run_command_in_image('python', '--version')
        self.assertEqual(result, f'Python {self._python_version}')

    def test_python_version_in_python(self):
        result = self._run_python_in_image(
            '''
import sys
print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')
''')
        self.assertEqual(result, f'{self._python_version}')

    def test_pip_version_command_line(self):
        result = self._run_command_in_image('pip', '--version')
        self.assertTrue(result.startswith(f'pip {self._pip_version}'))

    def test_sqlite(self):
        result = self._run_python_in_image(
            '''
import sqlite3
sqlite3.connect(':memory:')
''')
        self.assertEqual(result, '')

    def test_ssl(self):
        result = self._run_python_in_image(
            '''
import ssl
ciphers = ssl.create_default_context().get_ciphers()
if len(ciphers) > 0:
    print('found ciphers')
else:
    print('no ciphers found')
''')
        self.assertEqual(result, 'found ciphers')

    def test_install_numpy(self):
        result = self._run_command_in_image('pip', 'install', 'numpy')
        self.assertIn('Successfully installed numpy', result)

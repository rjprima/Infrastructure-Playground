import pytest
from algos import *
from pathlib import Path

def check_file(expressions: str, simplified: str):
    SCRIPT_DIR = Path(__file__).resolve().parent
    with open(SCRIPT_DIR / expressions) as exprs, open(SCRIPT_DIR / simplified) as ansrs:
        while True:
            expr = next(exprs, None)
            ansr = next(ansrs, None)
            if expr == None or ansr == None:
                break
            i = ansr.find('=')
            ansr = ansr[i+2:].strip()
            assert round(evaluate(expr), 5) == round(eval(ansr), 5)

def test_expressions1():
    check_file("../test_expressions1.txt", "../test_expressions1_answers.txt")

def test_expressions2():
    check_file("../test_expressions2.txt", "../test_expressions2_answers.txt")

def test_expressions3():
    check_file("../test_expressions3.txt", "../test_expressions3_answers.txt")
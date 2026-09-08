import ast
#from collections import deque
#import sys

def is_valid(expr: str) -> bool:
    try:
        node = ast.parse(expr.strip(), mode='eval')
    except (SyntaxError, ValueError):
        return False

    for n in ast.walk(node):
        if not isinstance(n, (
            ast.Expression,
            ast.BinOp,
            ast.UnaryOp,
            ast.Constant,
            ast.Add, ast.Sub, ast.Mult, ast.Div,
            ast.FloorDiv, ast.Mod, ast.Pow,
            ast.UAdd, ast.USub
        )):
            return False

    return True

def evaluate(expr: str) -> float:      
    ret = eval(expr)
    return float(ret)
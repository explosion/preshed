import pytest

from preshed.tries import SequenceIndex
from preshed.tries import _fmt_line
from preshed.tries import _parse_line


@pytest.fixture
def tree():
    return SequenceIndex()


def test_len1(tree):
    assert tree[5] == 0
    tree(5)
    assert tree(5) == tree[(5,)] == 1
    assert tree(2) == 2
    assert tree[5] == 1
    tree(7)
    assert tree(7) == 3
    assert tree[2] == 2
    assert tree[5] == 1
 

def test_len2(tree):
    assert tree[(0, 0)] == 0
    assert tree(0, 0) == 1
    assert tree[(0, 0)] == 1
    tree(0, 1)
    assert tree[(0, 0)] == 1
    assert tree[(0, 1)] == 2
    assert tree[(1, 0)] == 0
    tree(1, 0)
    assert tree[(1, 0)] == 3
    tree[(1, 1)]
    assert tree[(1, 1)] == 0
    assert tree(1, 1) == 4

    assert tree[(0, 0)] == 1
    assert tree[(0, 1)] == 2
    assert tree[(1, 0)] == 3

    assert tree[(0,)] == 0
    tree(0)
    assert tree[(0,)] == 5

    assert tree[(0, 0)] == 1
    assert tree[(0, 1)] == 2
    assert tree[(1, 0)] == 3
    assert tree[(1, 1)] == 4
    assert tree[(0,)] == 5


def test_revalue(tree):
    tree(0, 1)
    tree(1, 0)
    tree(0)
    new_values = [0, 10, 30, 20]
    tree.revalue(new_values)
    assert tree[0] == 20
    assert tree[(0, 1)] == 10
    assert tree[(1, 0)] == 30


def test_hash_backoff(tree):
    assert tree(1, 0, 0, 1000000) == 1
    assert tree.longest_node == 0
    assert tree(1, 0) == 2
    assert tree(1, 5) == 3
    assert tree(1, 10) == 4
    assert tree.longest_node == 11


def test_fmt_line():
    assert _fmt_line(15, [10]) == b'15\t10\n'
    assert _fmt_line(15, [10, 1]) == b'15\t10\t1\n'
    assert _fmt_line(5, [20, 2]) == b'5\t20\t2\n'

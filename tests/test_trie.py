import pytest

from preshed.tries import SequenceIndex
from preshed.tries import array_from_tuple


@pytest.fixture
def tree():
    return SequenceIndex()


def test_to_array():
    a = array_from_tuple((6, 2, 5, 7))
    assert len(a) == 4
    assert a[2] == 5
    assert a[3] == 7


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

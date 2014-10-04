import pytest

from preshed.tries import AddressTree
from preshed.tries import array_from_tuple


@pytest.fixture
def tree():
    return AddressTree()


def test_to_array():
    a = array_from_tuple((6, 2, 5, 7))
    assert len(a) == 4
    assert a[2] == 5
    assert a[3] == 7

def test_len1(tree):
    assert tree[(5,)] == None
    tree[(5,)] = 20
    assert tree[(5,)] == 20
    assert tree.first == 20
    assert tree.last == 20
    tree[(2,)] = 25
    assert tree[(2,)] == 25
    assert tree[(5,)] == 20
    assert tree.first == 25
    assert tree.last == 20
    tree[(7,)] = 30
    assert tree[(7,)] == 30
    assert tree[(2,)] == 25
    assert tree[(5,)] == 20
    assert tree.first == 25
    assert tree.last == 30
 

def test_len2(tree):
    assert tree[(0, 0)] == None
    tree[(0, 0)] = 1
    assert tree[(0, 0)] == 1
    tree[(0, 1)] = 2
    assert tree[(0, 0)] == 1
    assert tree[(0, 1)] == 2
    assert tree[(1, 0)] == None
    tree[(1, 0)] = 3
    assert tree[(1, 0)] == 3
    tree[(1, 1)] = 4
    assert tree[(1, 1)] == 4

    assert tree[(0, 0)] == 1
    assert tree[(0, 1)] == 2
    assert tree[(1, 0)] == 3

    assert tree[(0,)] == None
    tree[(0,)] = 5
    assert tree[(0,)] == 5

    assert tree[(0, 0)] == 1
    assert tree[(0, 1)] == 2
    assert tree[(1, 0)] == 3
    assert tree[(1, 1)] == 4

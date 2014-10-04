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

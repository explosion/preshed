import pytest

from preshed.maps import PreshMap
import random


def test_insert():
    h = PreshMap()
    assert h[1] is None
    h[1] = 5
    assert h[1] == 5
    h[2] = 6
    assert h[1] == 5
    assert h[2] == 6

def test_resize():
    h = PreshMap(4)
    for i in range(1, 100):
        value = int(i * (random.random() + 1))
        h[i] = value

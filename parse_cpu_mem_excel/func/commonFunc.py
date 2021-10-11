# provide common function
import time
def calcRowNum(row) -> int:
    return row - 2

def letterToNum(letter) -> int:
    dictLetterNum = {
        'A': 1,
        'B': 2,
        'C': 3,
        'D': 4,
        'E': 5,
        'F': 6,
        'G': 7,
        'H': 8,
        'I': 9,
        'J': 10,
        'K': 11,
        'L': 12,
        'M': 13,
        'N': 14,
        'O': 15,
        'P': 16,
        'Q': 17,
        'R': 18,
        'S': 19,
        'T': 20,
        'U': 21,
        'V': 22,
        'W': 23,
        'X': 24,
        'Y': 25,
        'Z': 26
    }
    return dictLetterNum[letter]

def calc_spent_time(func):
    def calc_spent(*args, **kwargs):
        tt0 = time.time()
        func(*args, **kwargs)
        tt1 = time.time()
        print(func.__name__ + " : " + "%.2f s" %(tt1 - tt0))
    return calc_spent

def trans_path(path):
    path = path.replace('\\','\\\\')
    return path
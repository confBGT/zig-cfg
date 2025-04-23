import re
import json

def splitcaps(string):
    return re.findall("[A-Z][^A-Z]*", string)

file = open("grammar.txt", "r")
grammar_string, sentence_string = file.read().split("\n\n")
file.close()

grammar = {}
terminals = set()
for line in grammar_string.splitlines():
    lhs, rhs = line.split(" => ")
    rhs = splitcaps(rhs)
    terminals = terminals | set(rhs)
    grammar.setdefault(lhs, []).append(rhs)

terminals = set(terminals)

for terminal in terminals:
    grammar.setdefault(terminal, []).append([f'"{terminal}"'])

for lhs, all_rhs in grammar.items():
    # rhs_string = " | ".join(" ".join(rhs) for rhs in all_rhs)
    # print(f"{lhs} -> {rhs_string}")
    for rhs in all_rhs:
        print(f"{lhs} : {" ".join(rhs)}")

# print()
# print(json.dumps(splitcaps(sentence_string)))

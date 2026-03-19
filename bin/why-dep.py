#!/usr/bin/env python3

import json
import subprocess
import pprint
import collections

class OrderedSet:
	def __init__(self):
		self._dict = {}
	def add(self, elem):
		self._dict[elem] = True
	def pop(self):
		k, v = self._dict.popitem()
		return k
	def update(self, elems):
		for e in elems:
			self.add(e)
	def __bool__(self):
		return bool(self._dict)

def decode_concatenated_json(input):
	dec = json.JSONDecoder()
	while True:
		input = input.lstrip()
		if not input:
			break
		doc, idx = dec.raw_decode(input)
		input = input[idx:]
		yield doc

class Finder:
	def __init__(self, target):
		self._imports = {}
		self._target = target
		self._importers = collections.defaultdict(set)
		self._pending = set()
		self._processed = set()

	def do_list_obj(self, output):
		path = output['ImportPath']
		self._processed.add(path)
		deps = output.get('Deps', [])
		imports = output.get('Imports', [])
		if self._target in deps:
			self._pending |= set(imports) - self._processed
		for imp in imports:
			self._importers[imp].add(path)

	def do_list(self, pkgs):
		#print('processing', pkgs)
		stdout = subprocess.run(['go', 'list', '-json']+list(pkgs), check=True, stdout=subprocess.PIPE).stdout
		docs = decode_concatenated_json(stdout.decode())
		for obj in docs:
			self.do_list_obj(obj)

	def run(self):
		while self._pending:
			pkgs = self._pending.copy()
			self.do_list(pkgs)
			self._pending -= pkgs

	def start_from(self, start):
		self._pending.add(start)
		self.run()

	def report(self):
		walked = set()
		pending = OrderedSet()
		pending.add(self._target)
		while pending:
			name = pending.pop()
			walked.add(name)
			rdeps = self._importers[name]
			for rdep in rdeps:
				print(f'{rdep} -> {name}')
			pending.update(set(rdeps)-walked)

def main():
	import argparse

	ap = argparse.ArgumentParser()
	ap.add_argument('--start', default='.')
	ap.add_argument('dep')
	ns = ap.parse_args()
	f = Finder(ns.dep)
	f.start_from(ns.start)
	f.report()

main()

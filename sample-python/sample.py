import sys
sys.path.append('..')
from Sifter import *
template = Sifter()
template.set_var('foo', 'bar')
template.set_var('condition', 'true')
template.set_var('array', [{'loop':1}, {'loop':2}, {'loop':3}])
template.display('sample.tmpl')

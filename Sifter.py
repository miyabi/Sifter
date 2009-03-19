##
# Sifter - a simple and functional template engine
# 
# $Id$
# 
# @package		Sifter
# @version		1.1.7
# @author		Masayuki Iwai <miyabi@mybdesign.com>
# @copyright	Copyright &copy; 2005-2009 Masayuki Iwai all rights reserved.
# @license		BSD license
##

"""
= NAME

Sifter - a simple and functional template engine

= SYNOPSIS

Example code:

  from Sifter import *
  template = Sifter()
  template.set_var('foo', 'bar')
  template.set_var('condition', 'True')
  template.set_var('array', [{'loop':1}, {'loop':2}, {'loop':3}])
  template.display('template_file')

Example template:

  foo = {foo}
  <!--@IF({condition}=='True')-->
  OK
  <!--@END_IF-->
  <!--@LOOP(array)-->
  loop = {loop}
  <!--@END_LOOP-->

Output:

  foo = bar
  OK
  loop = 1
  loop = 2
  loop = 3

= DESCRIPTION

This module is a simple and functional template engine.

= SEE ALSO

http://www.mybdesign.com/sifter/

= COPYRIGHT AND LICENSE

Copyright (c) 2005-2009 Masayuki Iwai All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

(1) Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.
(2) Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.
(3) Neither the names of the authors nor the names of their contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"""


import inspect, re, sys, types


################ Constant variables
SIFTER_VERSION = '1.0107'
SIFTER_PACKAGE = 'Sifter'

SIFTER_AVAILABLE_CONTROLS = r'LOOP|FOR|IF|ELSE|EMBED|NOBREAK|LITERAL|INCLUDE|\?'
SIFTER_CONTROL_EXPRESSION = r'((END_)?(' + SIFTER_AVAILABLE_CONTROLS + r'))(?:\((.*?)\))?'
SIFTER_DECIMAL_EXPRESSION = r'-?(?:\d*?\.\d+|\d+\.?)'
SIFTER_REPLACE_EXPRESSION = r'(#?[A-Za-z_]\w*?)(\s*[\+\-\*\/%]\s*' + SIFTER_DECIMAL_EXPRESSION + r')?(,\d*)?((?:\:|\/)\w+)?'
SIFTER_TAG_EXPRESSION = r'(?:[^\"\'>]|\"[^\"]*\"|\'[^\']*\')'
SIFTER_EMBED_EXPRESSION = r'<(?:input|\/?select)' + SIFTER_TAG_EXPRESSION + r'*>|<option' + SIFTER_TAG_EXPRESSION + r'*>.*?(?:<\/option>|[\r\n])|<textarea' + SIFTER_TAG_EXPRESSION + r'*>.*?<\/textarea>'
SIFTER_CONDITIONAL_EXPRESSION = r'((?:[^\'\?]+|(?:\'(?:\\.|[^\'])*?\'))+)\?\s*((?:\\.|[^:])*)\s*:\s*(.*)'


################ Global variables
SIFTER_CONTROL_TAG_BGN = r'<!--@'
SIFTER_CONTROL_TAG_END = r'-->'
SIFTER_CONTROL_PATTERN = r'^(.*?)(' + SIFTER_CONTROL_TAG_BGN + SIFTER_CONTROL_EXPRESSION + SIFTER_CONTROL_TAG_END + r')(.*)$'
SIFTER_REPLACE_TAG_BGN = r'\{'
SIFTER_REPLACE_TAG_END = r'\}'
SIFTER_REPLACE_PATTERN = SIFTER_REPLACE_TAG_BGN + SIFTER_REPLACE_EXPRESSION + SIFTER_REPLACE_TAG_END

SIFTER_SELECT_NAME = ''
SIFTER_DEBUG = None


################ Classes
class SifterElement:
	"""
	Template element class
	
	@package	Sifter
	"""

	######## Constructor
	def __init__(self, parent, type='', param='', embed_flag=0, nobreak_flag=0):
		"""
		Creates new SifterElement object
		
		@return	object
		@param	object	parent        Parent object
		@param	string	type          Type of this object
		@param	string	param         Parameter string
		@param	int		embed_flag    Embed flag
		@param	int		nobreak_flag  No-break flag
		"""

		######## Members
		##
		# Holds top level object
		# 
		# @var	object
		##
		self.top = None

		##
		# Holds template object
		# 
		# @var	object
		##
		self.template = None

		##
		# Holds parent object
		# 
		# @var	object
		##
		self.parent = None

		##
		# Type of this object
		# 
		# @var	string
		##
		self.type = ''

		##
		# Parameter string
		# 
		# @var	string
		##
		self.param = ''

		##
		# Holds child objects
		# 
		# @var	array
		##
		self.contents = []

		##
		# Count child objects
		# 
		# @var	int
		##
		self.content_index = -1

		##
		# Embed flag
		# 
		# @var	int
		##
		self.embed_flag = 0

		##
		# No-break flag
		# 
		# @var	int
		##
		self.nobreak_flag = 0

		##
		# Result of previous evaluation of condition
		# 
		# @var	bool
		##
		self.prev_eval_result = True

		if not parent: return None

		if parent._get_top():
			self.top = parent._get_top()
		else:
			self.top = parent

		if parent._get_template():
			self.template = parent._get_template()
		else:
			self.template = parent

		self.parent = parent
		self.type = type
		self.param = param

		self.embed_flag   = embed_flag
		self.nobreak_flag = nobreak_flag

	######## Methods
	def _get_top(self):
		"""
		Returns reference to top level object
		
		@return	object	Reference to top level object
		"""
		return self.top

	def _get_template(self):
		"""
		Returns reference to template object
		
		@return	object	Reference to template object
		"""
		return self.template

	def _get_parent(self):
		"""
		Returns reference to parent object
		
		@return	object	Reference to parent object
		"""
		return self.parent

	def _parse(self):
		"""
		Reads and parses template file
		
		@return	bool
		"""
		literal = (self.type == 'LITERAL')

		regexp = re.compile(SIFTER_CONTROL_PATTERN, re.S)
		i = 0
		while self.template.buffer != '' or self.template._read_line():
			matches = regexp.search(self.template.buffer)
			if matches:
				matches = (None,) + matches.groups()
			if not matches:
				# Text
				self._append_text(self.template.buffer)
				self.template.buffer = ''
				continue

			if literal and matches[3] != 'END_LITERAL':
				# LITERAL block
				self._append_text(matches[1] + matches[2])
				self.template.buffer = matches[7]
				self.template._set_preserve_spaces_flag(True)
				continue

			if matches[1] is not None and matches[7] is not None and re.search(r'[^\s]', matches[1] + matches[7]):
				self._append_text(matches[1])
				self.template.buffer = matches[7]
				self.template._set_preserve_spaces_flag(True)
			elif self.template._get_preserve_spaces_flag() or matches[3] == 'END_NOBREAK':
				self._append_text(re.sub(r'[^\r\n]', '', matches[1]))
				self.template.buffer = re.sub(r'[^\r\n]', '', matches[7])
			else:
				self.template.buffer = ''

			type_ = matches[5] if matches[5] else ''
			param = re.sub(r'^\s+|\s+$', '', matches[6]) if matches[6] else ''

			if matches[4]:
				# End of block
				if param == '' and (self.type == type_ or (self.type == 'ELSE' and (type_ == 'IF' or type_ == 'LOOP'))):
					return True
				else:
					self.template._raise_error(inspect.getlineno(sys._getframe())+1)
					return False

			if (type_ == 'LOOP' or type_ == 'FOR') and param != '':
				# LOOP, FOR block
				if not self._append_element(type_, param):
					return False
			elif type_ == 'IF' and param != '':
				# IF block
				param = Sifter._check_condition(param)
				if not param:
					return False
				if not self._append_element(type_, param):
					return False
			elif type_ == 'ELSE':
				# ELSE block
				if self.type == 'LOOP' and param == '':
					if not self.parent._append_element(type_, param):
						return False
					break
				elif self.type == 'IF' or self.type == 'ELSE':
					param = Sifter._check_condition(param)
					if param != '' and not param:
						self.template._raise_error(inspect.getlineno(sys._getframe())+1)
						return False
					if not self.parent._append_element(type_, param):
						return False
					break
				else:
					self.template._raise_error(inspect.getlineno(sys._getframe())+1)
					return False
			elif type_ == '?' and param != '':
				# ?
				condition = False
				matches = re.compile(SIFTER_CONDITIONAL_EXPRESSION).search(param)
				if matches:
					matches = (None,) + matches.groups()
					condition = Sifter._check_condition(matches[1])
				if not condition:
					self.template._raise_error(inspect.getlineno(sys._getframe())+1)
					return False
				if not self._append_element('IF', condition, True, re.sub(r'\\(.)', r'\1', matches[2])):
					return False
				if not self._append_element('ELSE', '', True, re.sub(r'\\(.)', r'\1', matches[3])):
					return False
			elif type_ == 'EMBED':
				# EMBED block
				param = param.lower()
				if param == '' or param == 'xml' or param == 'html':
					if not self._append_element(type_, 1 if param == 'html' else 3):
						return False
				else:
					self.template._raise_error(inspect.getlineno(sys._getframe())+1)
					return False
			elif (type_ == 'NOBREAK' or type_ == 'LITERAL') and param == '':
				# NOBREAK, LITERAL block
				if not self._append_element(type_, ''):
					return False
			elif type_ == 'INCLUDE' and param != '':
				# INCLUDE
				if not self._append_template(param):
					return False
			else:
				# Syntax error
				self.template._raise_error(inspect.getlineno(sys._getframe())+1)
				return False

		return True

	def _append_text(self, str):
		"""
		Appends string to this object
		
		@return	bool
		@param	string	str  String
		"""
		if str != '':
			if not self.contents or type(self.contents[self.content_index]) is not types.StringType:
				self.content_index += 1
				self.contents.append('')
			self.contents[self.content_index] += str

	def _append_element(self, type, param, noparse=False, str=''):
		"""
		Appends block to this object
		
		@return	bool
		@param	string	type     Type of this object
		@param	string	param    Paramenter string
		@param	bool	noparse  If this parameter is True, skips parsing added element
		@param	string	str      Additional string
		"""
		self.content_index += 1
		self.contents.append(
			SifterElement(
				self, type, param, 
				param if type == 'EMBED' else self.embed_flag, 
				1 if type == 'NOBREAK' else self.nobreak_flag
			)
		)

		if self.contents[self.content_index]:
			if not noparse:
				if not self.contents[self.content_index]._parse():
					return False

			if str and str != '':
				self.contents[self.content_index]._append_text(str)
			return True

		return False

	def _append_template(self, template_file):
		"""
		Appends block to this object
		
		@return	bool
		@param	string	template_file  Path to template file
		"""
		if template_file[0] != '/': template_file = self.template._get_dir_path() + '/' + template_file
		if self.template._is_recursive(template_file):
			self.template._raise_error(inspect.getlineno(sys._getframe())+1, 0, "'" + template_file + "' is included recursively")
			return False

		self.content_index += 1
		self.contents.append(SifterTemplate(self, template_file, self.embed_flag, self.nobreak_flag))
		if self.contents[self.content_index]:
			return self.contents[self.content_index]._parse()

		return False

	def _display_content(self, replace):
		"""
		Displays content
		
		@return	bool
		@param	array	replace  Array of replacement
		"""
		literal = (self.type == 'LITERAL')

		for content in self.contents:
			if type(content) is not types.StringType:
				if not content._display(replace):
					return False
			else:
				# Text
				if not literal:
					if self.nobreak_flag != 0:
						content = re.sub(r'[\r\n]', '', content)
					content = Sifter.format(content, replace)
					if self.embed_flag != 0:
						content = Sifter._embed_values(content, replace, (self.embed_flag&2 != 0))

				if self.top.capture_result:
					self.top._append_result(content)
				else:
					sys.stdout.write(content)

		return True

	def _display(self, replace):
		"""
		Applys template and displays
		
		@return	bool
		@param	array	replace  Array of replacement
		"""
		if self.type == 'LOOP':
			# LOOP block
			if type(replace[self.param]) is not types.ListType or len(replace[self.param]) <= 0:
				self.parent.prev_eval_result = False
				return True

			self.parent.prev_eval_result = True

			i = 0
			for temp in replace[self.param]:
				if type(temp) is not types.DictType: temp = {'#value': temp}

				temp = temp.copy()
				temp.update(replace)
				temp['#' + self.param + '_index'] = i

				if not self._display_content(temp): return False

				i += 1
		elif self.type == 'FOR':
			# FOR block
			matches = re.search(r'^(-?\d+),\s*(-?\d+)(?:,\s*(-?\d+))?$', Sifter.format(self.param, replace))
			if matches:
				matches = (None,) + matches.groups()
			if matches:
				j = int(matches[1])
				k = int(matches[2])
				l = int(matches[3]) if matches[3] else (1 if j<=k else -1)
				temp = replace.copy()
				i = j
				while (l>0 and i<=k) or (l<0 and i>=k):
					temp['#value'] = i
					if not self._display_content(temp): return False
					i += l
		elif self.type == 'IF' or (self.type == 'ELSE' and not self.parent.prev_eval_result):
			# IF, ELSE block
			if self.param == '' or eval(self.param):
				if not self._display_content(replace): return False
				self.parent.prev_eval_result = True
			else:
				self.parent.prev_eval_result = False
		elif self.type != 'ELSE':
			# Other types of block
			if not self._display_content(replace): return False

		return True

	def _display_tree(self, max_length=20, tabs=''):
		"""
		Displays template structure as a tree
		
		@param	int		max_length  Number of characters to display text
		@param	string	tabs        Tab characters
		"""
		if self.type != '':
			sys.stdout.write(tabs + "[" + self.type)
			if self.param != '': sys.stdout.write('(' + str(self.param) + ')')
			sys.stdout.write("]\n")
		else:
			sys.stdout.write(tabs + "[TEMPLATE:" + self.template.template_file + "]\n")

		for content in self.contents:
			if content.__class__ is SifterElement:
				content._display_tree(max_length, tabs + "\t")
			elif content.__class__ is SifterTemplate:
				content._display_tree(max_length, tabs + "\t")
			else:
				content = re.sub(r'[\r\n]', ' ', content)
				sys.stdout.write(tabs + "\t[TEXT:" + content[0:max_length] + "]\n")


class SifterTemplate:
	"""
	Template control class
	
	@package	Sifter
	"""

	######## Constructor
	def __init__(self, parent, template_file='', embed_flag=0, nobreak_flag=0):
		"""
		Creates new SifterTemplate object
		
		@return	object
		@param	object	parent         Parent object
		@param	string	template_file  Path to template file
		@param	int		embed_flag     Embed flag
		@param	int		nobreak_flag   No-break flag
		"""

		######## Members
		##
		# Holds top level object
		# 
		# @var	object
		##
		self.top = None

		##
		# Holds template object
		# 
		# @var	object
		##
		self.template = None

		##
		# Holds parent object
		# 
		# @var	object
		##
		self.parent = None

		##
		# Holds child objects
		# 
		# @var	object
		##
		self.contents = None

		##
		# Path to template file
		# 
		# @var	string
		##
		self.template_file = ''

		##
		# Path to directory includes template file
		# 
		# @var	string
		##
		self.dir_path = ''

		##
		# File pointer of template file
		# 
		# @var	resource
		##
		self.fp = None

		##
		# Buffer
		# 
		# @var	string
		##
		self.buffer = ''

		#
		# Buffer size
		# 
		# @var	int
		##
		self.buffer_size = 0

		##
		# Line number in currently reading file
		# 
		# @var	int
		##
		self.reading_line = 0

		##
		# Flag of preserving spaces in the line that includes control tags only
		# 
		# @var	bool
		##
		self.preserve_spaces = False

		##
		# Embed flag
		# 
		# @var	int
		##
		self.embed_flag = 0

		##
		# No-break flag
		# 
		# @var	int
		##
		self.nobreak_flag = 0

		if not parent: return None

		if parent.__class__ is Sifter or not parent._get_top():
			self.top = parent
			self.parent = None
		else:
			self.top = parent._get_top()
			self.parent = parent

		self.buffer_size = self.top._get_buffer_size()
		self._set_template_file(template_file)

		self.embed_flag   = embed_flag
		self.nobreak_flag = nobreak_flag

	######## Methods
	def _get_top(self):
		"""
		Returns reference to top level object
		
		@return	object	Reference to top level object
		"""
		return self.top

	def _get_template(self):
		"""
		Returns reference to template object
		
		@return	object	Reference to template object
		"""
		return self.template

	def _get_parent(self):
		"""
		Returns reference to parent object
		
		@return	object	Reference to parent object
		"""
		return self.parent

	def _set_template_file(self, template_file):
		"""
		Specifies path to template file
		
		@param	string	template_file  Path to template file
		"""
		self.template_file = template_file
		self._set_dir_path(template_file)

	def _get_template_file(self):
		"""
		Returns path to template file
		
		@return	string	Path to template file
		"""
		return self.template_file

	def _set_dir_path(self, template_file):
		"""
		Specifies path to directory includes template file
		
		@param	string	template_file  Path to template file
		"""
		matches = re.search(r'^(.*)\/', template_file)
		if matches:
			self.dir_path = matches.group(1)
		else:
			self.dir_path = '.'

	def _get_dir_path(self):
		"""
		Returns path to directory includes template file
		
		@return	string	Path to directory includes template file
		"""
		return self.dir_path

	def _set_preserve_spaces_flag(self, flag):
		"""
		Preserves spaces in the line that includes control tags only
		
		@param	bool	flag  If this parameter is true, spaces in the line that includes control tags only will be preserved
	"""
		self.preserve_spaces = flag

	def _get_preserve_spaces_flag(self):
		"""
		Returns true if spaces in the line that includes control tags only will be preserved
		
		@return	bool
		"""
		return self.preserve_spaces

	def _is_recursive(self, template_file):
		"""
		Returns True if specified template is included recursively
		
		@return	bool
		@param	string	template_file  Path to template file
		"""
		if self.template_file == template_file:
			return True
		elif self.parent:
			return self.parent.template._is_recursive(template_file)
		else:
			return False

	def _increment_file_line(self):
		"""
		Counts up line number in currently reading file
		
		"""
		self.reading_line += 1

	def _get_reading_line(self):
		"""
		Returns line number in currently reading file
		
		@return	int	Line number in currently reading file
		"""
		return self.reading_line

	def _read_line(self):
		"""
		Reads template file
		
		@return	bool
		"""
		if self.fp:
			self.buffer = self.fp.readline(self.buffer_size)
			if self.buffer:
				self._increment_file_line()
				self._set_preserve_spaces_flag(False)
				return True

		return False

	def _parse(self):
		"""
		Reads and parses template file
		
		@return	bool
		"""
		if not self.contents:
			self.contents = SifterElement(self, '', '', self.embed_flag, self.nobreak_flag)

		self.fp = open(self.template_file, 'rU')
		if not self.fp:
			sys.stdout.write(SIFTER_PACKAGE + ": Cannot open file '" + self.template_file + "'.\n")
			return False

		if not self.contents._parse():
			self.fp.close()

			if not self.parent:
				sys.stdout.write(SIFTER_PACKAGE + ": Error(s) occurred while parsing file '" + self.template_file + "'.\n")
				sys.stdout.write(SIFTER_PACKAGE + ": " + str(self._get_reading_line()) + " lines have been read.\n")

			return False

		self.fp.close()
		return True

	def _display(self, replace):
		"""
		Applys template and displays
		
		@return	string
		@param	array	replace  Array of replacement
		"""
		return self.contents._display(replace)

	def _display_tree(self, max_length=20, tabs=''):
		"""
		Displays template structure as a tree
		
		@return	bool
		@param	int		max_length  Number of characters to display text
		@param	string	tabs        Tab characters
		"""
		return self.contents._display_tree(max_length, tabs)

	def _raise_error(self, script_line=0, line=0, error=''):
		"""
		Displays syntax error
		
		@param	int		script_line  Line number in this script
		@param	int		line         Line number in currently reading file
		@param	string	error        Error string
		"""
		file_ = self._get_template_file()
		line = line if line else self._get_reading_line()
		error = error if error else 'Syntax error'
		sys.stdout.write(SIFTER_PACKAGE)
		if SIFTER_DEBUG:
			if script_line != 0:
				sys.stdout.write("(%(script_line)s)" % locals())
		sys.stdout.write(": %(error)s in %(file_)s on line %(line)s." % locals())
		sys.stdout.write("\n")


class Sifter:
	"""
	Template control class
	
	@package	Sifter
	"""

#!!	include SifterModule

#!!	attr_reader :capture_result, :reading_line

	######## Constructor
	def __init__(self, size=None):
		"""
		Creates new SifterTemplate object
		
		@return	bool
		@param	int		size  Buffer size in bytes
		"""

		######## Members
		##
		# Package name
		# 
		# @var	string
		##
		self.package = 'Sifter'

		##
		# Holds child objects
		# 
		# @var	object
		##
		self.contents = None

		##
		# Capture result flag
		# 
		# @var	bool
		##
		self.capture_result = False

		##
		# Result
		# 
		# @var	string
		##
		self.result = ''

		##
		# Buffer size in bytes
		# 
		# @var	int
		##
		self.buffer_size = 2048

		##
		# Holds replacements
		# 
		# @var	array
		##
		self.replace_vars = {}

		if size is not None:
			self.buffer_size = size

	######## Methods
	def _append_result(self, str):
		"""
		Appends result
		
		@param	str  String
		"""
		self.result += str

	def _get_buffer_size(self):
		"""
		Returns buffer size in bytes
		
		@return	resource	Buffer size in bytes
		"""
		return self.buffer_size

	def _get_var(self, name):
		"""
		Returns replacement specified by name
		
		@return	string	Replacement
		@param	string	name  Name of variable
		"""
		return self.replace_vars[name]

	def _parse(self, template_file):
		"""
		Reads and parses template file
		
		@return	bool
		@param	string	template_file  Path to template file
		"""
		if not self.contents:
			self.contents = SifterTemplate(self, template_file)
		else:
			self.contents.template_file = template_file

		return self.contents._parse()

	def _set_loop_count(self, replace):
		"""
		Set loop count value
		
		@param	array	replace  Array of replacement
		
		"""
		if type(replace) is not types.DictType: return
		for key in replace.keys():
			if type(replace[key]) is types.ListType and len(replace[key]) > 0:
				replace['#' + key + '_count'] = len(replace[key])
				for i in range(0, len(replace[key])):
					self._set_loop_count(replace[key][i])

	def set_control_tag(self, begin_tag, end_tag, escape=True):
		"""
		Specifies control tag characters
		
		@param	string	begin   Control tag characters (begin)
		@param	string	end     Control tag characters (end)
		@param	bool	escape  If this parameter is True, meta characters are escaped
		"""
		global SIFTER_CONTROL_TAG_BGN, SIFTER_CONTROL_TAG_END, SIFTER_CONTROL_PATTERN

		if escape:
			begin_tag = re.sub(r'([.*+?^\$\\|()\[\]])', r'\\\1', begin_tag)
			end_tag   = re.sub(r'([.*+?^\$\\|()\[\]])', r'\\\1', end_tag  )

		SIFTER_CONTROL_TAG_BGN = begin_tag
		SIFTER_CONTROL_TAG_END = end_tag  
		SIFTER_CONTROL_PATTERN = '^(.*?)(' + begin_tag + SIFTER_CONTROL_EXPRESSION + end_tag + ')(.*)$'

	def set_replace_tag(self, begin_tag, end_tag, escape=True):
		"""
		Specifies replace tag characters
		
		@param	string	begin   Replace tag characters (begin)
		@param	string	end     Replace tag characters (end)
		@param	bool	escape  If this parameter is True, meta characters are escaped
		"""
		global SIFTER_REPLACE_TAG_BGN, SIFTER_REPLACE_TAG_END, SIFTER_REPLACE_PATTERN

		if escape:
			begin_tag = re.sub(r'([.*+?^\$\\|()\[\]])', r'\\\1', begin_tag)
			end_tag   = re.sub(r'([.*+?^\$\\|()\[\]])', r'\\\1', end_tag  )

		SIFTER_REPLACE_TAG_BGN = begin_tag
		SIFTER_REPLACE_TAG_END = end_tag  
		SIFTER_REPLACE_PATTERN = begin_tag + SIFTER_REPLACE_EXPRESSION + end_tag

	def set_var(self, name, value, convert_html=True):
		"""
		Sets up replacements
		
		@param	string	name          Name of variable
		@param	mixed	value         Array or string
		@param	bool	convert_html  If this parameter is True, HTML entities are converted
		"""
		if convert_html:
			value = Sifter._convert_html_entities(value)

		self.replace_vars[name] = value

	def append_var(self, name, value, convert_html=True):
		"""
		Append loop variable
		
		@param	string	name          Name of variable
		@param	mixed	value         Array or string
		@param	bool	convert_html  If this parameter is True, HTML entities are converted
		"""
		if type(self.replace_vars[name]) is not types.ListType:
			return

		if convert_html:
			value = Sifter._convert_html_entities(value)

		self.replace_vars[name].append(value)

	def display(self, template_file, capture_result=False):
		"""
		Displays content
		
		@return	bool
		@param	string	template_file   Path to template file
		@param	bool	capture_result  If this parameter is True, does not display but returns string
		"""
		self.capture_result = capture_result

		self.contents = None
		self.result = ''

		if self._parse(template_file):
			if self.contents:
				self._set_loop_count(self.replace_vars)
				if self.contents._display(self.replace_vars):
					if self.capture_result:
						return self.result
					else:
						return True

		return False

	def display_tree(self, template_file, max_length=20):
		"""
		Displays template structure as a tree
		
		@return	bool
		@param	string	template_file  Path to template file
		@param	int		max_length     Number of characters to display text
		"""
		self.contents = None
		self.result = ''

		if self._parse(template_file):
			if self.contents:
				return self.contents._display_tree(max_length, '')

		return False

	######## Static methods
	@staticmethod
	def _check_condition(condition):
		"""
		Check condition string
		
		@return	string	Parsed condition
		@param	string	condition  Condition string
		"""
		elem1 = SIFTER_REPLACE_PATTERN
		elem2 = SIFTER_DECIMAL_EXPRESSION
		elem3 = r'\'(?:[^\'\\]|\\.)*\''
		elem4 = r'\((' + elem1 + r'|' + elem3 + r')\s*=~\s*\/((?:[^\/\\]|\\.)+)\/([imsx]*)\)'
		op1 = r'[\-~]|not'
		op2 = r'[+\-*\/%]|&|\||\^|<<|>>'
		op3 = r'==|!=|<>|>=?|<=?|is(?:\s+not)?|(?:not\s+)?in'
		op4 = r'and|or'

		if re.compile(r'|'.join([elem1, elem2, elem3, elem4, op3, op4, op1, op2]) + r'|[(),]|\s', re.I).sub('', condition) != '':
			return False
		else:
			condition = re.sub(
				r'(' + elem3 + r')', 
				lambda matches: Sifter._escape_replace_tags(matches.group(1)), 
				condition
			)
			condition = re.sub(
				elem4, 
				lambda matches: 
					're.compile(r\'' + Sifter._escape_replace_tags(matches.group(6)) + '\'' + 
					(',0' + re.sub(r'(.)', lambda matches: '|re.' + matches.group(1).upper(), matches.group(7)) if matches.group(7) else '') + 
					').search(' + matches.group(1) + ')',
				condition
			)
			condition = re.sub(
				elem1, 
				lambda matches: "replace['" + matches.group(1) + "']", 
				condition
			)

			return Sifter._unescape_replace_tags(condition)

	@staticmethod
	def _escape_replace_tags(str):
		"""
		Escape replace tags
		
		@return	string	String that includes escaped replace tags
		@param	string	str  Source string
		"""
		return re.sub(
			r'(' + SIFTER_REPLACE_TAG_BGN + r')(\\*?' + SIFTER_REPLACE_EXPRESSION + SIFTER_REPLACE_TAG_END + ')', 
			r'\1\\\2', 
			str
		)

	@staticmethod
	def _unescape_replace_tags(str):
		"""
		Unescape replace tags
		
		@return	string	String that includes unescaped replace tags
		@param	string	str  Source string
		"""
		return re.sub(
			r'(' + SIFTER_REPLACE_TAG_BGN + r')\\(.+?' + SIFTER_REPLACE_TAG_END + ')', 
			r'\1\2', 
			str
		)

	@staticmethod
	def _get_attribute(tag, name):
		"""
		Extracts attribute from tag
		
		@return	string	Value of attribute
		@param	string	tag   Tag
		@param	string	name  Name of attribute to extract
		"""
		matches = re.compile(r'\b' + name + r'=(?:\"([^\"]*)\"|\'([^\']*)\'|([^\s\/>]*))', re.I|re.S).search(tag)
		if matches:
			return (matches.group(1) or matches.group(2) or matches.group(3))

		return None

	@staticmethod
	def _set_attribute(tag, name, value, verbose=True):
		"""
		Sets attribute into tag
		
		@return	string	Tag set attribute
		@param	string	tag      Tag
		@param	string	name     Name of attribute to set
		@param	string	value    Value of attribute to set
		@param	bool	verbose  If this parameter is True, "checked" and "selected" attributes are output verbosely
		"""
		pattern = r'\b' + name + r'=(?:\"[^\"]*\"|\'[^\']*\'|[^>\s]*)'
		attr = name + (r'="' + value + r'"' if verbose else '')
		if re.compile(pattern, re.I|re.S).search(tag):
			ret = re.compile(pattern, re.I|re.S).sub(attr, tag)
		else:
			ret = re.compile(r'(<' + SIFTER_TAG_EXPRESSION + r'*?)(\s*\/>|>)', re.S).sub(r'\1 ' + attr + r'\2', tag, 1)

		return ret

	@staticmethod
	def _get_element_id(tag):
		"""
		Extracts id or name attribute from tag
		
		@return	string	Value of id or name attribute
		@param	string	tag  Tag
		"""
		ret = Sifter._get_attribute(tag, 'id')
		if not ret:
			ret = Sifter._get_attribute(tag, 'name')

		return ret

	@staticmethod
	def _embed_values_callback(str, values, verbose):
		"""
		Called by function _embed_values()
		
		@return	string	Value embedded string
		@param	string	str      Source string
		@param	array	values   Array of values to embed
		@param	bool	verbose  If this parameter is True, "checked" and "selected" attributes are output verbosely
		"""
		global SIFTER_SELECT_NAME

		element = ''
		matches = re.search(r'^<(\/?.+?)\b', str)
		if matches:
			element = matches.group(1)
		if element.lower() == 'input':
			name = Sifter._get_element_id(str)
			if name in values:
				type_ = Sifter._get_attribute(str, 'type')
				if type_.lower() == 'radio' or type_.lower() == 'checkbox':
					if Sifter._get_attribute(str, 'value') == values[name]:
						str = Sifter._set_attribute(str, 'checked', 'checked', verbose)
					else:
						str = re.compile(r'(<input.*)\s+checked(?:=(\"|\'|\b)checked\2)?(\s*\/?>)', re.I|re.S).sub(
							r'\1\3', str, 1
						)
				else:
					str = Sifter._set_attribute(str, 'value', values[name])
		elif element.lower() == 'textarea':
			name = Sifter._get_element_id(str)
			if name in values:
				str = re.compile(r'(<textarea\b.*?>).*?(<\/textarea>)', re.I|re.S).sub(
					lambda matches: matches.group(1) + values[name] + matches.group(2), str, 1
				)
		elif element.lower() == 'select':
			if SIFTER_SELECT_NAME == '':
				SIFTER_SELECT_NAME = re.sub(r'\[\]$', '', Sifter._get_element_id(str), 1)
		elif element.lower() == '/select':
			SIFTER_SELECT_NAME = ''
		elif element.lower() == 'option':
			if SIFTER_SELECT_NAME != '' and values[SIFTER_SELECT_NAME]:
				value = Sifter._get_attribute(str, 'value')
				if not value:
					matches = re.compile(r'<option\b.*?>(.*?)(?:<\/option>|[\r\n])', re.I).search(str);
					if matches:
						value = matches.group(1)

				if(
					(type(values[SIFTER_SELECT_NAME]) is types.ListType and values[SIFTER_SELECT_NAME].find(value) >= 0) or
					value == values[SIFTER_SELECT_NAME]
				):
					str = Sifter._set_attribute(str, 'selected', 'selected', verbose)
				else:
					str = re.compile(r'(<option.*)\s+selected(?:=(\"|\'|\b)selected\2)?(\s*\/?>)', re.I|re.S).sub(
						r'\1\3', str, 1
					)

		return str

	@staticmethod
	def _embed_values(str, values, verbose=True):
		"""
		Embed value into element of form
		
		@return	string		Value embedded string
		@param	resource	str      Reference to source string
		@param	array		values   Array of values to embed
		@param	bool		verbose  If this parameter is True, "checked" and "selected" attributes are output verbosely
		"""
		str = re.compile(r'(' + SIFTER_EMBED_EXPRESSION + r')', re.I|re.S).sub(
			lambda matches: Sifter._embed_values_callback(matches.group(1), values, verbose), 
			str
		)

		return str

	@staticmethod
	def _convert_html_entities(value):
		"""
		Convert HTML entities
		
		@param	mixed	value  String or array to convert
		"""
		if type(value) is types.ListType or type(value) is types.TupleType:
			for key in range(0, len(value)):
				value[key] = Sifter._convert_html_entities(value[key])
		elif type(value) is types.DictType:
			for key in value.iterkeys():
				value[key] = Sifter._convert_html_entities(value[key])
		elif type(value) is types.StringType:
			value = re.sub(r'\&', '&amp;', value)
			value = re.sub(r'\"', '&quot;', value)
			value = re.sub(r'\<', '&lt;', value)
			value = re.sub(r'\>', '&gt;', value)

		return value

	@staticmethod
	def _format_callback(value, comma='', options=''):
		"""
		Called by function format()
		
		@return	string	Formatted value
		@param	string	value    Value
		@param	string	comma    If this parameter is set, numeric value will be converted to comma formatted value
		@param	string	options  Options
		"""
		if comma and comma != '':
			comma = ',0' if not comma[1:].isdigit() else comma
			value = re.sub(r'^((' + SIFTER_DECIMAL_EXPRESSION + r')?).*', r'\1', value)
			temp = ('%.*f' % (int(comma[1:]), float('0' + value))).split('.')
			while 1:
				matches = re.search(r'(\d)(\d\d\d)(?!\d)', temp[0])
				if not matches: break
				temp[0] = matches.group(1) + ',' + matches.group(2)
			value = '.'.join(temp)
		elif re.search(r'^' + SIFTER_DECIMAL_EXPRESSION + r'$', value):
			temp = value.split('.')
			if len(temp) > 1 and int(temp[1]) == 0: value = temp[0]

		if options and options != '':
			if options.find('b') >= 0:
				# Convert linebreaks to "<br />"
				value = re.sub(r'(\r?\n)', r'<br />\1', value)
			if options.find('q') >= 0:
				# Escape quotes, backslashes and linebreaks
				value = re.sub(r'([\"\'\\]|&quot;)', lambda matches: '\\' + matches.group(1), value)
				value = re.sub(r'\r', r'\\r', value)
				value = re.sub(r'\n', r'\\n', value)

		return value

	@staticmethod
	def _format(replace, key, operation='', comma='', options=''):
		"""
		Called by function format()
		
		@return	string	Formatted value
		@param	array	replace    Array of replacement
		@param	string	key        Value
		@param	string	operation  Arithmetic operation
		@param	string	comma      If this parameter is set, numeric value will be converted to comma formatted value
		@param	string	options    Options
		"""
		if type(replace) is not types.DictType: return ''

		value = str(replace[key]) if key in replace else ''

		if operation and operation != '':
			value = re.sub(r'^((' + SIFTER_DECIMAL_EXPRESSION + r')?).*', r'\1', value)
			value = 0 if value == '' else value
			value = eval(str(value) + operation)

		return Sifter._format_callback(str(value), comma, options)

	@staticmethod
	def format(format, replace):
		"""
		Format string
		
		@return	string	Formatted string
		@param	string	format   Format string
		@param	array	replace  Array of replacement
		"""
		return re.sub(
			SIFTER_REPLACE_PATTERN, 
			lambda matches: 
				Sifter._format(replace, matches.group(1), matches.group(2), matches.group(3), matches.group(4)), 
			format
		)

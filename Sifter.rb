##
# Sifter - a simple and functional template engine
# 
# $Id$
# 
# @package		Sifter
# @version		1.1.5
# @author		Masayuki Iwai <miyabi@mybdesign.com>
# @copyright	Copyright &copy; 2005-2008 Masayuki Iwai all rights reserved.
# @license		BSD license
##

=begin
= NAME

Sifter - a simple and functional template engine

= SYNOPSIS

Example code:

  require(Sifter);
  template = Sifter.new;
  template.set_var('foo', 'bar');
  template.set_var('condition', 'true');
  template.set_var('array', [{'loop'=>1}, {'loop'=>2}, {'loop'=>3}]);
  template.display('template_file');

Example template:

  foo = {foo}
  <!--@IF({condition}=='true')-->
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

Copyright (c) 2005-2008 Masayuki Iwai All rights reserved.

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
=end


module SifterModule

################ Constant variables
SIFTER_VERSION = '1.0105';
SIFTER_PACKAGE = 'Sifter';

SIFTER_AVAILABLE_CONTROLS = 'LOOP|FOR|IF|ELSE|EMBED|NOBREAK|LITERAL|INCLUDE|\?';
SIFTER_CONTROL_EXPRESSION = '((END_)?(' + SIFTER_AVAILABLE_CONTROLS + '))(?:\((.*?)\))?';
SIFTER_DECIMAL_EXPRESSION = '-?(?:\d*?\.\d+|\d+\.?)';
SIFTER_REPLACE_EXPRESSION = '(#?[A-Za-z_]\w*?)(\s*[\+\-\*\/%]\s*' + SIFTER_DECIMAL_EXPRESSION + ')?(,\d*)?((?:\:|\/)\w+)?';
SIFTER_EMBED_EXPRESSION = '<(?:input|\/?select)\b.*?>|<option\b.*?>.*?(?:<\/option>|[\r\n])|<textarea\b.*?>.*?<\/textarea>';
SIFTER_CONDITIONAL_EXPRESSION = '((?:[^\'\?]+|(?:\'(?:\\\\.|[^\'])*?\'))+)\?\s*((?:\\\\.|[^:])*)\s*:\s*(.*)';


################ Global variables
@@SIFTER_CONTROL_TAG_BGN = '<!--@';
@@SIFTER_CONTROL_TAG_END = '-->';
@@SIFTER_CONTROL_PATTERN = '^(.*?)(' + @@SIFTER_CONTROL_TAG_BGN + SIFTER_CONTROL_EXPRESSION + @@SIFTER_CONTROL_TAG_END + ')(.*)$';
@@SIFTER_REPLACE_TAG_BGN = '\{';
@@SIFTER_REPLACE_TAG_END = '\}';
@@SIFTER_REPLACE_PATTERN = @@SIFTER_REPLACE_TAG_BGN + SIFTER_REPLACE_EXPRESSION + @@SIFTER_REPLACE_TAG_END;

@@SIFTER_SELECT_NAME = '';
@@SIFTER_LINE_BREAK = "\n";

end


################ Classes
##
# Template element class
# 
# @package	Sifter
##
class SifterElement

	include SifterModule;

	attr_accessor :prev_eval_result;

	######## Constructor
	##
	# Creates new SifterElement object
	# 
	# @return	object
	# @param	object	parent        Parent object
	# @param	string	type          Type of this object
	# @param	string	param         Parameter string
	# @param	int		embed_flag    Embed flag
	# @param	int		nobreak_flag  No-break flag
	##
	def initialize(parent, type='', param='', embed_flag=0, nobreak_flag=0)
		######## Members
		##
		# Holds top level object
		# 
		# @var	object
		##
		@top = nil;

		##
		# Holds template object
		# 
		# @var	object
		##
		@template = nil;

		##
		# Holds parent object
		# 
		# @var	object
		##
		@parent = nil;

		##
		# Type of this object
		# 
		# @var	string
		##
		@type = '';

		##
		# Parameter string
		# 
		# @var	string
		##
		@param = '';

		##
		# Holds child objects
		# 
		# @var	array
		##
		@contents = [];

		##
		# Count child objects
		# 
		# @var	int
		##
		@content_index = -1;

		##
		# Embed flag
		# 
		# @var	int
		##
		@embed_flag = 0;

		##
		# No-break flag
		# 
		# @var	int
		##
		@nobreak_flag = 0;

		##
		# Result of previous evaluation of condition
		# 
		# @var	bool
		##
		@prev_eval_result = true;

		return nil if(!parent);

		if(parent._get_top())
			@top = parent._get_top();
		else
			@top = parent;
		end

		if(parent._get_template())
			@template = parent._get_template();
		else
			@template = parent;
		end

		@parent = parent;
		@type = type;
		@param = param;

		@embed_flag   = embed_flag;
		@nobreak_flag = nobreak_flag;
	end

	######## Methods
	##
	# Returns reference to top level object
	# 
	# @return	object	Reference to top level object
	##
	def _get_top()
		return @top;
	end

	##
	# Returns reference to template object
	# 
	# @return	object	Reference to template object
	##
	def _get_template()
		return @template;
	end

	##
	# Returns reference to parent object
	# 
	# @return	object	Reference to parent object
	##
	def _get_parent()
		return @parent;
	end

	##
	# Reads and parses template file
	# 
	# @return	bool
	##
	def _parse()
		literal = (@type == 'LITERAL');

		i = 0;
		while(@template.buf != '' || @template._read_line())
			matches = Array(/#{@@SIFTER_CONTROL_PATTERN}/mo.match(@template.buf));
			if(matches.length <= 0)
				# Text
				self._append_text(@template.buf);
				@template.buf = '';
				next;
			end

			if(literal && matches[3] != 'END_LITERAL')
				# LITERAL block
				self._append_text(matches[1] + matches[2]);
				@template.buf = matches[7];
				@template._set_preserve_spaces_flag(true);
				next;
			end

			if(matches[1] && matches[7] && /[^\s]/.match(matches[1] + matches[7]))
				self._append_text(matches[1]);
				@template.buf = matches[7];
				@template._set_preserve_spaces_flag(true);
			elsif(@template._get_preserve_spaces_flag() || matches[3] == 'END_NOBREAK')
				self._append_text(matches[1].gsub(/[^\r\n]/, ''));
				@template.buf = matches[7];
				@template.buf.gsub!(/[^\r\n]/, '');
			else
				@template.buf = '';
			end

			type = (matches[5]? matches[5]: '');
			param = (matches[6]? matches[6]: '').gsub(/^\s+|\s+$/, '');

			if(matches[4])
				# End of block
				if(
					param == '' && 
					(@type == type || (@type == 'ELSE' && (type == 'IF' || type == 'LOOP')))
				)
					return true;
				else
					@template._raise_error(__LINE__);
					return false;
				end
			end

			if((type == 'LOOP' || type == 'FOR') && param != '')
				# LOOP, FOR block
				if(!self._append_element(type, param))
					return false;
				end
			elsif(type == 'IF' && param != '')
				# IF block
				if(!(param = Sifter._check_condition(param)))
					return false;
				end
				if(!self._append_element(type, param))
					return false;
				end
			elsif(type == 'ELSE')
				# ELSE block
				if(@type == 'LOOP' && param == '')
					if(!@parent._append_element(type, param))
						return false;
					end
					break;
				elsif(@type == 'IF' || @type == 'ELSE')
					if(param != '' && !(param = Sifter._check_condition(param)))
						@template._raise_error(__LINE__);
						return false;
					end
					if(!@parent._append_element(type, param))
						return false;
					end
					break;
				else
					@template._raise_error(__LINE__);
					return false;
				end
			elsif(type == '?' && param != '')
				# ?
				matches = Array(/#{SIFTER_CONDITIONAL_EXPRESSION}/.match(param));
				if(matches.length <= 0 || !(matches[1] = Sifter._check_condition(matches[1])))
					@template._raise_error(__LINE__);
					return false;
				end
				if(!self._append_element('IF', matches[1], true, matches[2].gsub(/\\(.)/, '\\1')))
					return false;
				end
				if(!self._append_element('ELSE', '', true, matches[3].gsub(/\\(.)/, '\\1')))
					return false;
				end
			elsif(type == 'EMBED')
				# EMBED block
				param.downcase!;
				if(param == '' || param == 'xml' || param == 'html')
					if(!self._append_element(type, (param == 'html')? 1: 3))
						return false;
					end
				else
					@template._raise_error(__LINE__);
					return false;
				end
			elsif((type == 'NOBREAK' || type == 'LITERAL') && param == '')
				# NOBREAK, LITERAL block
				if(!self._append_element(type, ''))
					return false;
				end
			elsif(type == 'INCLUDE' && param != '')
				# INCLUDE
				if(!self._append_template(param))
					return false;
				end
			else
				# Syntax error
				@template._raise_error(__LINE__);
				return false;
			end
		end

		return true;
	end

	##
	# Appends string to this object
	# 
	# @return	bool
	# @param	string	str  String
	##
	def _append_text(str)
		if(str != '')
			if(!@contents || !@contents[@content_index].is_a?(String))
				@content_index += 1;
				@contents[@content_index] = '';
			end
			@contents[@content_index] += str;
		end
	end

	##
	# Appends block to this object
	# 
	# @return	bool
	# @param	string	type     Type of this object
	# @param	string	param    Paramenter string
	# @param	bool	noparse  If this parameter is true, skips parsing added element
	# @param	string	str      Additional string
	##
	def _append_element(type, param, noparse=false, str='')
		if(
			@contents[@content_index += 1] = SifterElement.new(
				self, type, param, 
				((type == 'EMBED'  )? param.to_int: @embed_flag  ), 
				((type == 'NOBREAK')? 1           : @nobreak_flag)
			)
		)
			if(!noparse)
				if(!@contents[@content_index]._parse())
					return false;
				end
			end

			@contents[@content_index]._append_text(str) if(str && str != '');
			return true;
		end

		return false;
	end

	##
	# Appends block to this object
	# 
	# @return	bool
	# @param	string	template_file  Path to template file
	##
	def _append_template(template_file)
		template_file = @template._get_dir_path() + '/' + template_file if(template_file[0].chr != '/');
		if(@template._is_recursive(template_file))
			@template._raise_error(__LINE__, 0, "'#{template_file}' is included recursively");
			return false;
		end

		if(
			@contents[@content_index += 1] = SifterTemplate.new(
				self, template_file, @embed_flag, @nobreak_flag
			)
		)
			return @contents[@content_index]._parse();
		end

		return false;
	end

	##
	# Displays content
	# 
	# @return	bool
	# @param	array	replace  Array of replacement
	##
	def _display_content(replace)
		literal = (@type == 'LITERAL');

		for content in @contents
			if(!content.is_a?(String))
				return false if(!content._display(replace));
			else
				# Text
				if(!literal)
					content.gsub!(/[\r\n]/, '') if(@nobreak_flag != 0);
					content = Sifter.format(content, replace);
					Sifter._embed_values(content, replace, (@embed_flag&2 != 0)) if(@embed_flag != 0);
				end

				if(@top._does_capture_result())
					@top._append_result(content);
				else
					print(content);
				end
			end
		end

		return true;
	end

	##
	# Applys template and displays
	# 
	# @return	bool
	# @param	array	replace      Array of replacement
	##
	def _display(replace)
		if(@type == 'LOOP')
			# LOOP block
			if(!replace[@param].is_a?(Array) || replace[@param].length <= 0)
				@parent.prev_eval_result = false;
				return true;
			end

			@parent.prev_eval_result = true;

			count = replace[@param].length;
			i = 0;
			for temp in replace[@param]
				temp = {'#value'=>temp} if(!temp.is_a?(Hash));

				temp = temp.merge(replace);
				temp['#' + @param + '_index'] = i;
				temp['#' + @param + '_count'] = count;

				return false if(!self._display_content(temp));

				i += 1;
			end
		elsif(@type == 'FOR')
			# FOR block
			if(/^(-?\d+),\s*(-?\d+)(?:,\s*(-?\d+))?$/.match(Sifter.format(@param, replace)))
				j = Regexp.last_match[1].to_i;
				k = Regexp.last_match[2].to_i;
				l = (Regexp.last_match[3]? Regexp.last_match[3].to_i: ((j<=k)? 1: -1));
				temp = replace;
				i = j
				while((l>0 && i<=k) || (l<0 && i>=k))
					temp['#value'] = i;
					return false if(!self._display_content(temp));
					i += l;
				end
			end
		elsif(@type == 'IF' || (@type == 'ELSE' && !@parent.prev_eval_result))
			# IF, ELSE block
			if(@param == '' || ((temp = eval(@param)) && temp != 0))
				return false if(!self._display_content(replace));
				@parent.prev_eval_result = true;
			else
				@parent.prev_eval_result = false;
			end
		elsif(@type != 'ELSE')
			# Other types of block
			return false if(!self._display_content(replace));
		end

		return true;
	end

	##
	# Displays template structure as a tree
	# 
	# @param	int		max_length  Number of characters to display text
	# @param	string	tabs        Tab characters
	##
	def _display_tree(max_length=20, tabs='')
		if(@type != '')
			print(tabs + "[" + @type + ((@param != '')? '(' + @param + ')': '') + "]\n");
		else
			print(tabs + "[TEMPLATE:" + @template._get_template_file() + "]\n");
		end

		for content in @contents
			if(content.is_a?(SifterElement))
				content._display_tree(max_length, tabs + "\t");
			elsif(content.is_a?(SifterTemplate))
				content._display_tree(max_length, tabs + "\t");
			else
				content.gsub!(/[\r\n]/, ' ');
				print(tabs + "\t[TEXT:" + content[0, max_length] + "]\n");
			end
		end
	end

end


##
# Template control class
# 
# @package	Sifter
##
class SifterTemplate

	include SifterModule;

	attr_accessor :buf;

	######## Constructor
	##
	# Creates new SifterTemplate object
	# 
	# @return	object
	# @param	object	parent         Parent object
	# @param	string	template_file  Path to template file
	# @param	int		embed_flag     Embed flag
	# @param	int		nobreak_flag   No-break flag
	##
	def initialize(parent, template_file='', embed_flag=0, nobreak_flag=0)
		######## Members
		##
		# Holds top level object
		# 
		# @var	object
		##
		@top = nil;

		##
		# Holds template object
		# 
		# @var	object
		##
		@template = nil;

		##
		# Holds parent object
		# 
		# @var	object
		##
		@parent = nil;

		##
		# Holds child objects
		# 
		# @var	object
		##
		@contents = nil;

		##
		# Path to template file
		# 
		# @var	string
		##
		@template_file = '';

		##
		# Path to directory includes template file
		# 
		# @var	string
		##
		@dir_path = '';

		##
		# File pointer of template file
		# 
		# @var	resource
		##
		@fp = nil;

		##
		# Buffer
		# 
		# @var	resource
		##
		@buf = '';

		##
		# Buffer size
		# 
		# @var	int
		##
		@buf_size = 0;

		##
		# Line number in currently reading file
		# 
		# @var	int
		##
		@reading_line = 0;

		##
		# Flag of preserving spaces in the line that includes control tags only
		# 
		# @var	bool
		##
		@preserve_spaces = false;

		##
		# Embed flag
		# 
		# @var	int
		##
		@embed_flag = 0;

		##
		# No-break flag
		# 
		# @var	int
		##
		@nobreak_flag = 0;

		return nil if(!parent);

		if(parent.is_a?(Sifter) || !parent._get_top())
			@top = parent;
			@parent = nil;
		else
			@top = parent._get_top();
			@parent = parent;
		end

		@buf_size = @top._get_buffer_size();
		@template_file = template_file;
		@dir_path = (/^(.*)\//.match(template_file)? Regexp.last_match[1]: '.');
	end

	######## Methods
	##
	# Returns reference to top level object
	# 
	# @return	object	Reference to top level object
	##
	def _get_top()
		return @top;
	end

	##
	# Returns reference to template object
	# 
	# @return	object	Reference to template object
	##
	def _get_template()
		return @template;
	end

	##
	# Returns reference to parent object
	# 
	# @return	object	Reference to parent object
	##
	def _get_parent()
		return @parent;
	end

	##
	# Specifies path to template file
	# 
	# @param	string	template_file  Path to template file
	##
	def _set_template_file(template_file)
		@template_file = template_file;
		self._set_dir_path(template_file);
	end

	##
	# Returns path to template file
	# 
	# @return	string	Path to template file
	##
	def _get_template_file()
		return @template_file;
	end

	##
	# Specifies path to directory includes template file
	# 
	# @param	string	template_file  Path to template file
	##
	def _set_dir_path(template_file)
		@dir_path = (/^(.*)\//.match(template_file)? Regexp.last_match[1]: '.');
	end

	##
	# Returns path to directory includes template file
	# 
	# @return	string	Path to directory includes template file
	##
	def _get_dir_path()
		return @dir_path;
	end

	##
	# Preserves spaces in the line that includes control tags only
	# 
	# @param	bool	flag  If this parameter is true, spaces in the line that includes control tags only will be preserved
	##
	def _set_preserve_spaces_flag(flag)
		@preserve_spaces = flag;
	end

	##
	# Returns true if spaces in the line that includes control tags only will be 
	# 
	# @return	bool
	##
	def _get_preserve_spaces_flag()
		return @preserve_spaces;
	end

	##
	# Returns true if specified template is included recursively
	# 
	# @return	bool
	# @param	string	template_file  Path to template file
	##
	def _is_recursive(template_file)
		return true if(@template_file == template_file);
		return @parent._get_template()._is_recursive(template_file) if(@parent);
		return false;
	end

	##
	# Returns reference to buffer
	# 
	# @return	resource	Reference to buffer
	##
	def _get_buffer()
		return @buf;
	end

	##
	# Counts up line number in currently reading file
	# 
	##
	def _increment_file_line()
		@reading_line += 1;
	end

	##
	# Returns line number in currently reading file
	# 
	# @return	int	Line number in currently reading file
	##
	def _get_file_line()
		return @reading_line;
	end

	##
	# Reads template file
	# 
	# @return	bool
	##
	def _read_line()
		if(@fp && (@buf = @fp.gets))
			self._increment_file_line();
			self._set_preserve_spaces_flag(false);
			return true;
		end

		return false;
	end

	##
	# Reads and parses template file
	# 
	# @return	bool
	##
	def _parse()
		@contents = SifterElement.new(self) if(!@contents);

#		my $fp;
#		local *fp;
		if(!(@fp = File.open(@template_file, 'r')))
			print("#{SIFTER_PACKAGE}: Cannot open file '#{@template_file}'.\n");
			return false;
		end

		line_break = $/;
		$/ = @@SIFTER_LINE_BREAK if(@@SIFTER_LINE_BREAK);

		if(!@contents._parse())
			$/ = line_break;
			@fp.close;

			if(!@parent)
				print("#{SIFTER_PACKAGE}: Error(s) occurred while parsing file '#{@template_file}'.\n");
				print("#{SIFTER_PACKAGE}: " + self._get_file_line().to_s + " lines have been read.\n");
			end
			return false;
		end

		$/ = line_break;
		@fp.close;
		return true;
	end

	##
	# Applys template and displays
	# 
	# @return	string
	# @param	array	replace  Array of replacement
	##
	def _display(replace)
		return @contents._display(replace);
	end

	##
	# Displays template structure as a tree
	# 
	# @return	bool
	# @param	int		max_length  Number of characters to display text
	# @param	string	tabs        Tab characters
	##
	def _display_tree(max_length=20, tabs='')
		return @contents._display_tree(max_length, tabs);
	end

	##
	# Displays syntax error
	# 
	# @param	int		script_line  Line number in this script
	# @param	int		line         Line number in currently reading file
	# @param	string	error        Error string
	##
	def _raise_error(script_line=0, line=0, error='')
		file = self._get_template_file();
		line = ((line != 0)? line: self._get_file_line());
		error = ((error != '')? error: 'Syntax error');
		print(SIFTER_PACKAGE);
		print((script_line != 0)? "(#{script_line})": "") if(defined?(Sifter::SIFTER_DEBUG));
		print(": #{error} in #{file} on line #{line}.\n");
	end

end


##
# Template control class
# 
# @package	Sifter
##
class Sifter

	include SifterModule;

	######## Constructor
	##
	# Creates new SifterTemplate object
	# 
	# @return	bool
	# @param	string	template_file  Path to template file
	# @param	string	buf_size       Buffer size in bytes
	##
	def initialize(buf_size=nil)
		######## Members
		##
		# Package name
		# 
		# @var	string
		##
		@package = 'Sifter';

		##
		# Holds child objects
		# 
		# @var	object
		##
		@contents = nil;

		##
		# Capture result flag
		# 
		# @var	bool
		##
		@capture_result = false;

		##
		# Result
		# 
		# @var	string
		##
		@result = '';

		##
		# Buffer size in bytes
		# 
		# @var	int
		##
		@buf_size = 2048;

		##
		# Holds replacements
		# 
		# @var	array
		##
		@replace_vars = {};

		@buf_size = buf_size if(buf_size);
	end

	######## Methods
	##
	# Returns if does capture result
	# 
	# @return	bool
	##
	def _does_capture_result()
		return @capture_result;
	end

	##
	# Appends result
	# 
	# @param	$str  String
	##
	def _append_result(str)
		@result += str;
	end

	##
	# Returns buffer size in bytes
	# 
	# @return	resource	Buffer size in bytes
	##
	def _get_buffer_size()
		return @buf_size;
	end

	##
	# Returns replacement specified by name
	# 
	# @return	string	Replacement
	# @param	string	name  Name of variable
	##
	def _get_var(name)
		return @replace_vars[name];
	end

	##
	# Reads and parses template file
	# 
	# @return	bool
	# @param	string	template_file  Path to template file
	##
	def _parse(template_file)
		if(!@contents)
			@contents = SifterTemplate.new(self, template_file);
		else
			@contents._set_template_file(template_file);
		end

		return @contents._parse();
	end

	##
	# Specifies control tag characters
	# 
	# @param	string	begin   Control tag characters (begin)
	# @param	string	end     Control tag characters (end)
	# @param	bool	escape  If this parameter is true, meta characters are escaped
	##
	def set_control_tag(begin_tag, end_tag, escape=true)
		if(escape)
			begin_tag = begin_tag.gsub(/([.*+?^\$\\|()\[\]])/, '\\\\1');
			end_tag   = end_tag  .gsub(/([.*+?^\$\\|()\[\]])/, '\\\\1');
		end

		@@SIFTER_CONTROL_TAG_BGN = begin_tag;
		@@SIFTER_CONTROL_TAG_END = end_tag  ;
		@@SIFTER_CONTROL_PATTERN = '^(.*?)(' + begin_tag + SIFTER_CONTROL_EXPRESSION + end_tag + ')(.*)$';
	end

	##
	# Specifies replace tag characters
	# 
	# @param	string	begin   Replace tag characters (begin)
	# @param	string	end     Replace tag characters (end)
	# @param	bool	escape  If this parameter is true, meta characters are escaped
	##
	def set_replace_tag(begin_tag, end_tag, escape=true)
		if(escape)
			begin_tag.gsub(/([.*+?^\$\\|()\[\]])/, '\\\\1');
			end_tag  .gsub(/([.*+?^\$\\|()\[\]])/, '\\\\1');
		end

		@@SIFTER_REPLACE_TAG_BGN = begin_tag;
		@@SIFTER_REPLACE_TAG_END = end_tag  ;
		@@SIFTER_REPLACE_PATTERN = begin_tag + SIFTER_REPLACE_EXPRESSION + end_tag;
	end

	##
	# Sets up replacements
	# 
	# @param	string	name          Name of variable
	# @param	mixed	value         Array or string
	# @param	bool	convert_html  If this parameter is true, HTML entities are converted
	##
	def set_var(name, value, convert_html=true)
		Sifter._convert_html_entities(value) if(convert_html);
		@replace_vars[name] = value;
	end

	##
	# Append loop variable
	# 
	# @param	string	name          Name of variable
	# @param	mixed	value         Array or string
	# @param	bool	convert_html  If this parameter is true, HTML entities are converted
	##
	def append_var(name, value, convert_html=true)
		return if(!@replace_vars[name].is_a?(Array));

		Sifter._convert_html_entities(value) if(convert_html);
		@replace_vars[name].push(value);
	end

	##
	# Displays content
	# 
	# @return	bool
	# @param	string	template_file   Path to template file
	# @param	bool	capture_result  If this parameter is true, does not display but returns string
	##
	def display(template_file, capture_result=false)
		@capture_result = capture_result;

		if(self._parse(template_file))
			if(@contents)
				if(@contents._display(@replace_vars))
					return (self._does_capture_result()? @result: true);
				end
			end
		end

		return false;
	end

	##
	# Displays template structure as a tree
	# 
	# @return	bool
	# @param	string	template_file  Path to template file
	# @param	int		max_length     Number of characters to display text
	##
	def display_tree(template_file, max_length=20)
		if(self._parse(template_file))
			if(@contents)
				return @contents._display_tree(max_length, '');
			end
		end

		return false;
	end

	######## Class methods
	##
	# Check condition string
	# 
	# @return	string	Parsed condition
	# @param	string	condition  Condition string
	##
	def self._check_condition(condition)
		elem1 = @@SIFTER_REPLACE_PATTERN;
		elem2 = SIFTER_DECIMAL_EXPRESSION;
		elem3 = '\'(?:[^\'\\\\]|\\\\.)*\'';
		elem4 = '\((' + elem1 + '|' + elem3 + ')\s*=~\s*(\/(?:[^\/\\\\]|\\\\.)+\/[imsx]*)\)';
		op1 = '[\-~!]';
		op2 = '[+\-*\/%]|&|\||\^|<<|>>';
		op3 = '==|!=|>=?|<=?';
		op4 = 'and|or|xor|&&|\|\|';

		if(condition.gsub(/#{elem1}|#{elem2}|#{elem3}|#{elem4}|#{op3}|#{op4}|#{op1}|#{op2}|[()]|\s/io, '') != '')
			return false;
		else
			condition = condition.gsub(/(#{elem3})/o) {
				Sifter._escape_replace_tags(Regexp.last_match[1])
			};
			condition = condition.gsub(/#{elem4}/o) {
				Sifter._escape_replace_tags(Regexp.last_match[6]) + '.match(' + Regexp.last_match[1] + ')'
			};
			condition = condition.gsub(/#{elem1}/o) {
				"replace['" + Regexp.last_match[1] + "']"
			};

			return Sifter._unescape_replace_tags(condition);
		end
	end

	##
	# Escape replace tags
	# 
	# @return	string	String that includes escaped replace tags
	# @param	string	str  Source string
	##
	def self._escape_replace_tags(str)
		return str.gsub(/(#{@@SIFTER_REPLACE_TAG_BGN})(\\*?#{SIFTER_REPLACE_EXPRESSION}#{@@SIFTER_REPLACE_TAG_END})/o, '\\1\\\\2');
	end

	##
	# Unescape replace tags
	# 
	# @return	string	String that includes unescaped replace tags
	# @param	string	str  Source string
	##
	def self._unescape_replace_tags(str)
		return str.gsub(/(#{@@SIFTER_REPLACE_TAG_BGN})\\(.+?#{@@SIFTER_REPLACE_TAG_END})/o, '\\1\\2');
	end

	##
	# Extracts attribute from tag
	# 
	# @return	string	Value of attribute
	# @param	string	tag   Tag
	# @param	string	name  Name of attribute to extract
	##
	def self._get_attribute(tag, name)
		if(/\b#{name}=(\'|\"|\b)([^\1]*?)\1(?:\s|\/?>)/im.match(tag))
			return Regexp.last_match[2];
		end

		return nil;
	end

	##
	# Sets attribute into tag
	# 
	# @return	string	Tag set attribute
	# @param	string	tag      Tag
	# @param	string	name     Name of attribute to set
	# @param	string	value    Value of attribute to set
	# @param	bool	verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
	##
	def self._set_attribute(tag, name, value, verbose=true)
		pattern = '\b' + name + '=(\'|"|\b)[^\1]*?\1(\s|\/?>)';
		attr = name + ((verbose)? '="' + value + '"': '');
		if(/#{pattern}/im.match(tag))
			ret = tag.gsub(/#{pattern}/im, attr + '\\2');
		else
			ret = tag.sub(/<([^\/]+?)(\s*\/?)>/m, '<\\1 ' + attr + '\\2>');
		end

		return ret;
	end

	##
	# Extracts id or name attribute from tag
	# 
	# @return	string	Value of id or name attribute
	# @param	string	tag  Tag
	##
	def self._get_element_id(tag)
		if(!(ret = Sifter._get_attribute(tag, 'id')))
			ret = Sifter._get_attribute(tag, 'name');
		end

		return ret;
	end

	##
	# Called by function _embed_values()
	# 
	# @return	string	Value embedded string
	# @param	string	str      Source string
	# @param	array	values   Array of values to embed
	# @param	bool	verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
	##
	def self._embed_values_callback(str, values, verbose)
		element = Regexp.last_match[1] if(/^<(\/?.+?)\b/.match(str));
		if(element.casecmp('input') == 0)
			name = Sifter._get_element_id(str);
			if(values[name])
				type = Sifter._get_attribute(str, 'type');
				if(type.casecmp('radio') == 0 || type.casecmp('checkbox') == 0)
					if(Sifter._get_attribute(str, 'value') == values[name])
						str = Sifter._set_attribute(str, 'checked', 'checked', verbose);
					else
						str = str.sub(/(<input.*)\s+checked(?:=(\"|\'|\b)checked\2)?(\s*\/?>)/im, '\\1\\3');
					end
				else
					str = Sifter._set_attribute(str, 'value', values[name]);
				end
			end
		elsif(element.casecmp('textarea') == 0)
			name = Sifter._get_element_id(str);
			if(values[name])
				str = str.sub(/(<textarea\b.*?>).*?(<\/textarea>)/im) {
					Regexp.last_match[1] + values[name] + Regexp.last_match[2]
				};
			end
		elsif(element.casecmp('select') == 0)
			if(@@SIFTER_SELECT_NAME == '')
				@@SIFTER_SELECT_NAME = Sifter._get_element_id(str).sub(/\[\]$/, '');
			end
		elsif(element.casecmp('/select') == 0)
			@@SIFTER_SELECT_NAME = '';
		elsif(element.casecmp('option') == 0)
			if(@@SIFTER_SELECT_NAME != '' && values[@@SIFTER_SELECT_NAME])
				if(!(value = Sifter._get_attribute(str, 'value')))
					value = Regexp.last_match[1] if(/<option\b.*?>(.*?)(?:<\/option>|[\r\n])/i.match(str));
				end

				if(
					(values[@@SIFTER_SELECT_NAME].is_a?(Array) && values[@@SIFTER_SELECT_NAME].include?(value)) || 
					value == values[@@SIFTER_SELECT_NAME]
				)
					str = Sifter._set_attribute(str, 'selected', 'selected', verbose);
				else
					str = str.sub(/(<option.*)\s+selected(?:=(\"|\'|\b)selected\2)?(\s*\/?>)/im, '\\1\\3');
				end
			end
		end

		return str;
	end

	##
	# Embed value into element of form
	# 
	# @return	string		Value embedded string
	# @param	resource	str      Reference to source string
	# @param	array		values   Array of values to embed
	# @param	bool		verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
	##
	def self._embed_values(str, values, verbose=true)
		str.gsub!(/(#{SIFTER_EMBED_EXPRESSION})/imo) {
			Sifter._embed_values_callback(Regexp.last_match[1], values, verbose)
		};
	end

	##
	# Convert HTML entities
	# 
	# @param	mixed	value  String or array to convert
	##
	def self._convert_html_entities(value)
		if(value.is_a?(Array))
			for key in 0..value.length-1
				Sifter._convert_html_entities(value[key]);
			end
		elsif(value.is_a?(Hash))
			for key in value.keys
				Sifter._convert_html_entities(value[key]);
			end
		elsif(value.is_a?(String))
			value.gsub!(/\&/, '&amp;');
			value.gsub!(/\"/, '&quot;');
			value.gsub!(/\</, '&lt;');
			value.gsub!(/\>/, '&gt;');
		end
	end

	##
	# Called by function format()
	# 
	# @return	string	Formatted value
	# @param	string	value    Value
	# @param	string	comma    If this parameter is set, numeric value will be converted to comma formatted value
	# @param	string	options  Options
	##
	def self._format_callback(value, comma='', options='')
		if(comma && comma != '')
			value = value.gsub(/^((#{SIFTER_DECIMAL_EXPRESSION})?).*/, '\\1');

			temp = sprintf('%.*f', comma[1..-1].to_i, value.to_f).split('.');
			1 while(temp[0].gsub!(/(\d)(\d\d\d)(?!\d)/, '\\1,\\2'));
			value = temp.join('.');
		elsif(/^#{SIFTER_DECIMAL_EXPRESSION}$/.match(value))
			temp = value.split('.');
			value = temp[0] if(temp[1].to_i == 0);
		end

		if(options && options != '')
			if(options.index('b'))
				# Convert linebreaks to "<br />"
				value = value.gsub(/(\r?\n)/, '<br />\\1');
			end
			if(options.index('q'))
				# Escape quotes, backslashes and linebreaks
				value = value.gsub(/([\'\"\\]|&quot;)/) {'\\' + Regexp.last_match[1]};
				value = value.gsub(/\r/, '\\r');
				value = value.gsub(/\n/, '\\n');
			end
		end

		return value;
	end

	##
	# Format string
	# 
	# @return	string	Formatted string
	# @param	string	format   Format string
	# @param	array	replace  Array of replacement
	##
	def self.format(format, replace)
		return format.gsub(/#{@@SIFTER_REPLACE_PATTERN}/o) {
			Sifter._format_callback(
				Regexp.last_match[2]? 
					eval(replace[Regexp.last_match[1]].to_s + Regexp.last_match[2] + '.to_f').to_s: 
					replace[Regexp.last_match[1]].to_s, 
				Regexp.last_match[3], Regexp.last_match[4]
			)
		};
	end

end

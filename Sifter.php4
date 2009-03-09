<?php

/**
 * Sifter - a simple and functional template engine
 * 
 * $Id$
 * 
 * @package		Sifter
 * @version		1.1.6
 * @author		Masayuki Iwai <miyabi@mybdesign.com>
 * @copyright	Copyright &copy; 2005-2009 Masayuki Iwai all rights reserved.
 * @license		BSD license
 **/


/****************************************************************

NAME

Sifter - a simple and functional template engine

SYNOPSIS

Example code:

  require('Sifter.php');
  $template = new Sifter;
  $template->set_var('foo', 'bar');
  $template->set_var('condition', 'true');
  $template->set_var('array', array(array('loop'=>1), array('loop'=>2), array('loop'=>3)));
  $template->display('template_file');

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

DESCRIPTION

This module is a simple and functional template engine.

SEE ALSO

http://www.mybdesign.com/sifter/

COPYRIGHT AND LICENSE

Copyright (c) 2005-2009 Masayuki Iwai All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. Neither the names of the authors nor the names of their contributors
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

****************************************************************/


//////////////// Constant variables
define('SIFTER_VERSION', '1.0106');
define('SIFTER_PACKAGE', 'Sifter');

define('SIFTER_AVAILABLE_CONTROLS', 'LOOP|FOR|IF|ELSE|EMBED|NOBREAK|LITERAL|INCLUDE|\?');
define('SIFTER_CONTROL_EXPRESSION', '((END_)?('.SIFTER_AVAILABLE_CONTROLS.'))(?:\((.*?)\))?');
define('SIFTER_DECIMAL_EXPRESSION', '-?(?:\d*?\.\d+|\d+\.?)');
define('SIFTER_REPLACE_EXPRESSION', '(#?[A-Za-z_]\w*?)(\s*[\+\-\*\/%]\s*'.SIFTER_DECIMAL_EXPRESSION.')?(,\d*)?((?:\:|\/)\w+)?');
define('SIFTER_EMBED_EXPRESSION', '<(?:input|\/?select)\b.*?>|<option\b.*?>.*?(?:<\/option>|[\r\n])|<textarea\b.*?>.*?<\/textarea>');
define('SIFTER_CONDITIONAL_EXPRESSION', '((?:[^\'\?]+|(?:\'(?:\\\\.|[^\'])*?\'))+)\?\s*((?:\\\\.|[^:])*)\s*:\s*(.*)');


//////////////// Global variables
$SIFTER_CONTROL_TAG_BGN = '<!--@';
$SIFTER_CONTROL_TAG_END = '-->';
$SIFTER_CONTROL_PATTERN = '^(.*?)('.$SIFTER_CONTROL_TAG_BGN.SIFTER_CONTROL_EXPRESSION.$SIFTER_CONTROL_TAG_END.')(.*)$';
$SIFTER_REPLACE_TAG_BGN = '\{';
$SIFTER_REPLACE_TAG_END = '\}';
$SIFTER_REPLACE_PATTERN = $SIFTER_REPLACE_TAG_BGN.SIFTER_REPLACE_EXPRESSION.$SIFTER_REPLACE_TAG_END;

$SIFTER_SELECT_NAME = '';


//////////////// Classes
/**
 * Template element class
 * 
 * @package	Sifter
 **/
class SifterElement
{
	//////// Members
	/**
	 * Holds top level object
	 * 
	 * @var	object
	 **/
	var $top = null;

	/**
	 * Holds template object
	 * 
	 * @var	object
	 **/
	var $template = null;

	/**
	 * Holds parent object
	 * 
	 * @var	object
	 **/
	var $parent = null;

	/**
	 * Type of this object
	 * 
	 * @var	string
	 **/
	var $type = '';

	/**
	 * Parameter string
	 * 
	 * @var	string
	 **/
	var $param = '';

	/**
	 * Holds child objects
	 * 
	 * @var	array
	 **/
	var $contents = array();

	/**
	 * Count child objects
	 * 
	 * @var	int
	 **/
	var $content_index = -1;

	/**
	 * Embed flag
	 * 
	 * @var	int
	 **/
	var $embed_flag = 0;

	/**
	 * No-break flag
	 * 
	 * @var	int
	 **/
	var $nobreak_flag = 0;

	/**
	 * Result of previous evaluation of condition
	 * 
	 * @var	bool
	 **/
	var $prev_eval_result = true;

	//////// Constructor
	/**
	 * Creates new SifterElement object
	 * 
	 * @return	bool
	 * @param	object	$parent        Parent object
	 * @param	string	$type          Type of this object
	 * @param	string	$param         Parameter string
	 * @param	int		$embed_flag    Embed flag
	 * @param	int		$nobreak_flag  No-break flag
	 **/
	function SifterElement(&$parent, $type='', $param='', $embed_flag=0, $nobreak_flag=0)
	{
		if(is_null($parent)) return false;

		if(!is_null($parent->_get_top()))
			$this->top =& $parent->_get_top();
		else
			$this->top =& $parent;

		if(!is_null($parent->_get_template()))
			$this->template =& $parent->_get_template();
		else
			$this->template =& $parent;

		$this->parent =& $parent;
		$this->type = $type;
		$this->param = $param;

		$this->embed_flag   = $embed_flag;
		$this->nobreak_flag = $nobreak_flag;

		return true;
	}

	//////// Methods
	/**
	 * Returns reference to top level object
	 * 
	 * @return	object	Reference to top level object
	 **/
	function &_get_top()
	{
		return $this->top;
	}

	/**
	 * Returns reference to template object
	 * 
	 * @return	object	Reference to template object
	 **/
	function &_get_template()
	{
		return $this->template;
	}

	/**
	 * Returns reference to parent object
	 * 
	 * @return	object	Reference to parent object
	 **/
	function &_get_parent()
	{
		return $this->parent;
	}

	/**
	 * Reads and parses template file
	 * 
	 * @return	bool
	 **/
	function _parse()
	{
		global $SIFTER_CONTROL_PATTERN;

		$buf =& $this->template->_get_buffer();
		if(is_null($buf)) return false;

		$literal = ($this->type == 'LITERAL');

		while($buf != '' || $this->template->_read_line())
		{
			if(!preg_match('/'.$SIFTER_CONTROL_PATTERN.'/s', $buf, $matches))
			{
				// Text
				$this->_append_text($buf);
				$buf = '';
				continue;
			}

			if($literal && $matches[3] != 'END_LITERAL')
			{
				// LITERAL block
				$this->_append_text($matches[1].$matches[2]);
				$buf = $matches[7];
				$this->template->_set_preserve_spaces_flag(true);
				continue;
			}

			if(preg_match('/[^\s]/', $matches[1].$matches[7]))
			{
				$this->_append_text($matches[1]);
				$buf = $matches[7];
				$this->template->_set_preserve_spaces_flag(true);
			}
			else if($this->template->_get_preserve_spaces_flag() || $matches[3] == 'END_NOBREAK')
			{
				$this->_append_text(preg_replace('/[^\r\n]/', '', $matches[1]));
				$buf = preg_replace('/[^\r\n]/', '', $matches[7]);
			}
			else
			{
				$buf = '';
			}

			$type = $matches[5];
			$param = trim($matches[6]);

			if($matches[4])
			{
				// End of block
				if(
					$param == '' && 
					($this->type == $type || ($this->type == 'ELSE' && ($type == 'IF' || $type == 'LOOP')))
				)
				{
					return true;
				}
				else
				{
					$this->template->_raise_error(__LINE__);
					return false;
				}
			}

			if(($type == 'LOOP' || $type == 'FOR') && $param != '')
			{
				// LOOP, FOR block
				if(!$this->_append_element($type, $param))
					return false;
			}
			else if($type == 'IF' && $param != '')
			{
				// IF block
				if(($param = Sifter::_check_condition($param)) === false)
				{
					$this->template->_raise_error(__LINE__);
					return false;
				}
				if(!$this->_append_element($type, $param))
					return false;
			}
			else if($type == 'ELSE')
			{
				// ELSE block
				if($this->type == 'LOOP' && $param == '')
				{
					if(!$this->parent->_append_element($type, $param))
						return false;

					break;
				}
				else if($this->type == 'IF' || $this->type == 'ELSE')
				{
					if($param != '' && ($param = Sifter::_check_condition($param)) === false)
					{
						$this->template->_raise_error(__LINE__);
						return false;
					}
					if(!$this->parent->_append_element($type, $param))
						return false;

					break;
				}
				else
				{
					$this->template->_raise_error(__LINE__);
					return false;
				}
			}
			else if($type == '?' && $param != '')
			{
				// ?
				if(
					!preg_match('/'.SIFTER_CONDITIONAL_EXPRESSION.'/', $param, $matches) ||
					($matches[1] = Sifter::_check_condition($matches[1])) === false
				)
				{
					$this->template->_raise_error(__LINE__);
					return false;
				}
				if(!$this->_append_element('IF', $matches[1], true, stripslashes($matches[2])))
					return false;
				if(!$this->_append_element('ELSE', '', true, stripslashes($matches[3])))
					return false;
			}
			else if($type == 'EMBED')
			{
				// EMBED block
				$param = strtolower($param);
				if($param == '' || $param == 'xml' || $param == 'html')
				{
					if(!$this->_append_element($type, ($param == 'html')? 1: 3))
						return false;
				}
				else
				{
					$this->template->_raise_error(__LINE__);
					return false;
				}
			}
			else if(($type == 'NOBREAK' || $type == 'LITERAL') && $param == '')
			{
				// NOBREAK, LITERAL block
				if(!$this->_append_element($type, ''))
					return false;
			}
			else if($type == 'INCLUDE' && $param != '')
			{
				// INCLUDE
				if(!$this->_append_template($param))
					return false;
			}
			else
			{
				// Syntax error
				$this->template->_raise_error(__LINE__);
				return false;
			}
		}

		return true;
	}

	/**
	 * Appends string to this object
	 * 
	 * @return	bool
	 * @param	string	$str  String
	 **/
	function _append_text($str)
	{
		if($str != '')
		{
			if(!$this->contents || is_object($this->contents[$this->content_index]))
			{
				array_push($this->contents, '');
				$this->content_index++;
			}
			$this->contents[$this->content_index] .= $str;
		}
	}

	/**
	 * Appends block to this object
	 * 
	 * @return	bool
	 * @param	string	$type     Type of this object
	 * @param	string	$param    Parameter string
	 * @param	bool	$noparse  If this parameter is true, skips parsing added element
	 * @param	string	$str      Additional string
	 **/
	function _append_element($type, $param, $noparse=false, $str='')
	{
		if(
			$this->contents[++$this->content_index] = new SifterElement(
				$this, $type, $param, 
				(($type == 'EMBED'  )? $param: $this->embed_flag  ), 
				(($type == 'NOBREAK')? 1     : $this->nobreak_flag)
			)
		)
		{
			if(!$noparse)
				if(!$this->contents[$this->content_index]->_parse())
					return false;

			if($str != '')
				$this->contents[$this->content_index]->_append_text($str);

			return true;
		}

		return false;
	}

	/**
	 * Appends block to this object
	 * 
	 * @return	bool
	 * @param	string	$template_file  Path to template file
	 **/
	function _append_template($template_file)
	{
		if(substr($template_file, 0, 1) != '/')
			$template_file = $this->template->_get_dir_path().'/'.$template_file;

		if($this->template->_is_recursive($template_file))
		{
			$this->template->_raise_error(__LINE__, 0, "'$template_file' is included recursively");
			return false;
		}

		if(
			$this->contents[++$this->content_index] = new SifterTemplate(
				$this, $template_file, $this->embed_flag, $this->nobreak_flag
			)
		)
		{
			return $this->contents[$this->content_index]->_parse();
		}
	}

	/**
	 * Displays content
	 * 
	 * @return	bool
	 * @param	array	$replace  Array of replacement
	 **/
	function _display_content(&$replace)
	{
		$literal = ($this->type == 'LITERAL');

		foreach($this->contents as $content)
		{
			if(is_object($content))
			{
				if(!$content->_display($replace))
					return false;
			}
			else
			{
				// Text
				if(!$literal)
				{
					if($this->nobreak_flag)
						$content = preg_replace('/[\r\n]/', '', $content);

					$content = Sifter::format($content, $replace);
					if($this->embed_flag)
						Sifter::_embed_values($content, $replace, ($this->embed_flag&2)? 1: 0);
				}

				if($this->top->_does_capture_result())
					$this->top->_append_result($content);
				else
					print($content);
			}
		}

		return true;
	}

	/**
	 * Applys template and displays
	 * 
	 * @return	bool
	 * @param	array	$replace  Array of replacement
	 **/
	function _display(&$replace)
	{
		if($this->type == 'LOOP')
		{
			// LOOP block
			if(!(
				isset($replace[$this->param]) && is_array($replace[$this->param]) && count($replace[$this->param]) > 0
			))
			{
				$this->parent->prev_eval_result = false;
				return true;
			}

			$this->parent->prev_eval_result = true;

			$i = 0;
			foreach($replace[$this->param] as $temp)
			{
				if(!is_array($temp))
					$temp = array('#value'=>$temp);

				$temp += $replace;
				$temp['#'.$this->param.'_index'] = $i;

				if(!$this->_display_content($temp))
					return false;

				$i++;
			}
		}
		else if($this->type == 'FOR')
		{
			// FOR block
			if(preg_match('/^(-?\d+),\s*(-?\d+)(?:,\s*(-?\d+))?$/', Sifter::format($this->param, $replace), $matches))
			{
				$j = $matches[1];
				$k = $matches[2];
				$l = ((count($matches) > 3 && $matches[3])? $matches[3]: (($j<=$k)? 1: -1));
				$temp = $replace;
				for($i=$j; ($l>0 && $i<=$k) || ($l<0 && $i>=$k); $i+=$l)
				{
					$temp['#value'] = $i;
					if(!$this->_display_content($temp))
						return false;
				}
			}
		}
		else if($this->type == 'IF' || ($this->type == 'ELSE' && !$this->parent->prev_eval_result))
		{
			// IF, ELSE block
			if($this->param == '' || @eval('return ('.$this->param.');'))
			{
				if(!$this->_display_content($replace))
					return false;

				$this->parent->prev_eval_result = true;
			}
			else
			{
				$this->parent->prev_eval_result = false;
			}
		}
		else if($this->type != 'ELSE')
		{
			// Other types of block
			if(!$this->_display_content($replace))
				return false;
		}

		return true;
	}

	/**
	 * Displays template structure as a tree
	 * 
	 * @param	int		$max_length  Number of characters to display text
	 * @param	string	$tabs        Tab characters
	 **/
	function _display_tree($max_length=20, $tabs='')
	{
		if($this->type)
			print($tabs."[".$this->type.(($this->param != '')? '('.$this->param.')': '')."]\n");
		else
			print($tabs."[TEMPLATE:".$this->template->_get_template_file()."]\n");

		foreach($this->contents as $content)
		{
			if(strcasecmp(get_class($content), 'SifterElement') == 0)
				$content->_display_tree($max_length, $tabs."\t");
			else if(strcasecmp(get_class($content), 'SifterTemplate') == 0)
				$content->_display_tree($max_length, $tabs."\t");
			else
				print($tabs."\t[TEXT:".substr(preg_replace('/[\r\n]/', ' ', $content), 0, $max_length)."]\n");
		}
	}
}


/**
 * Template class
 * 
 * @package	Sifter
 **/
class SifterTemplate
{
	//////// Members
	/**
	 * Holds top level object
	 * 
	 * @var	object
	 **/
	var $top = null;

	/**
	 * Holds template object
	 * 
	 * @var	object
	 **/
	var $template = null;

	/**
	 * Holds parent object
	 * 
	 * @var	object
	 **/
	var $parent = null;

	/**
	 * Holds child objects
	 * 
	 * @var	object
	 **/
	var $contents = null;

	/**
	 * Path to template file
	 * 
	 * @var	string
	 **/
	var $template_file = '';

	/**
	 * Path to directory includes template file
	 * 
	 * @var	string
	 **/
	var $dir_path = '';

	/**
	 * File pointer of template file
	 * 
	 * @var	resource
	 **/
	var $fp = null;

	/**
	 * Buffer
	 * 
	 * @var	resource
	 **/
	var $buffer = '';

	/**
	 * Buffer size
	 * 
	 * @var	int
	 **/
	var $buffer_size = 0;

	/**
	 * Line number in currently reading file
	 * 
	 * @var	int
	 **/
	var $reading_line = 0;

	/**
	 * Flag of preserving spaces in the line that includes control tags only
	 * 
	 * @var	bool
	 **/
	var $preserve_spaces = false;

	/**
	 * Embed flag
	 * 
	 * @var	int
	 **/
	var $embed_flag = 0;

	/**
	 * No-break flag
	 * 
	 * @var	int
	 **/
	var $nobreak_flag = 0;

	//////// Constructor
	/**
	 * Creates new SifterTemplate object
	 * 
	 * @return	bool
	 * @param	object	$parent         Parent object
	 * @param	string	$template_file  Path to template file
	 * @param	int		$embed_flag     Embed flag
	 * @param	int		$nobreak_flag   No-break flag
	 **/
	function SifterTemplate(&$parent, $template_file='', $embed_flag=0, $nobreak_flag=0)
	{
		if(is_null($parent)) return false;

		if(strcasecmp(get_class($parent), 'Sifter') == 0 || is_null($parent->_get_top()))
		{
			$this->top =& $parent;
			$this->parent = null;
		}
		else
		{
			$this->top =& $parent->_get_top();
			$this->parent =& $parent;
		}

		$this->buffer_size = $this->top->_get_buffer_size();
		$this->_set_template_file($template_file);

		$this->embed_flag   = $embed_flag;
		$this->nobreak_flag = $nobreak_flag;

		return true;
	}

	//////// Methods
	/**
	 * Returns reference to top level object
	 * 
	 * @return	object	Reference to top level object
	 **/
	function &_get_top()
	{
		return $this->top;
	}

	/**
	 * Returns reference to template object
	 * 
	 * @return	object	Reference to template object
	 **/
	function &_get_template()
	{
		return $this->template;
	}

	/**
	 * Returns reference to parent object
	 * 
	 * @return	object	Reference to parent object
	 **/
	function &_get_parent()
	{
		return $this->parent;
	}

	/**
	 * Specifies path to template file
	 * 
	 * @param	string	$template_file  Path to template file
	 **/
	function _set_template_file($template_file)
	{
		$this->template_file = $template_file;
		$this->_set_dir_path($template_file);
	}

	/**
	 * Returns path to template file
	 * 
	 * @return	string	Path to template file
	 **/
	function _get_template_file()
	{
		return $this->template_file;
	}

	/**
	 * Specifies path to directory includes template file
	 * 
	 * @param	string	$template_file  Path to template file
	 **/
	function _set_dir_path($template_file)
	{
		$this->dir_path = (preg_match('/^(.*)\//', $template_file, $matches)?  $matches[1]: '.');
	}

	/**
	 * Returns path to directory includes template file
	 * 
	 * @return	string	Path to directory includes template file
	 **/
	function _get_dir_path()
	{
		return $this->dir_path;
	}

	/**
	 * Preserves spaces in the line that includes control tags only
	 * 
	 * @param	bool	$flag  If this parameter is true, spaces in the line that includes control tags only will be preserved
	 **/
	function _set_preserve_spaces_flag($flag)
	{
		$this->preserve_spaces = $flag;
	}

	/**
	 * Returns true if spaces in the line that includes control tags only will be preserved
	 * 
	 * @return	bool
	 **/
	function _get_preserve_spaces_flag()
	{
		return $this->preserve_spaces;
	}

	/**
	 * Returns true if specified template is included recursively
	 * 
	 * @return	bool
	 * @param	string	$template_file  Path to template file
	 **/
	function _is_recursive($template_file)
	{
		if($this->template_file == $template_file)
		{
			return true;
		}
		else if(!is_null($this->parent))
		{
			$template =& $this->parent->_get_template();
			if(!is_null($template))
				return $template->_is_recursive($template_file);
		}
		else
		{
			return false;
		}
	}

	/**
	 * Returns reference to buffer
	 * 
	 * @return	resource	Reference to buffer
	 **/
	function &_get_buffer()
	{
		return $this->buffer;
	}

	/**
	 * Counts up line number in currently reading file
	 * 
	 **/
	function _increment_file_line()
	{
		$this->reading_line++;
	}

	/**
	 * Returns line number in currently reading file
	 * 
	 * @return	int	Line number in currently reading file
	 **/
	function _get_reading_line()
	{
		return $this->reading_line;
	}

	/**
	 * Reads template file
	 * 
	 * @return	bool
	 **/
	function _read_line()
	{
		if($this->fp && $this->buffer = @fgets($this->fp, $this->buffer_size))
		{
			$this->_increment_file_line();
			$this->_set_preserve_spaces_flag(false);
			return true;
		}

		return false;
	}

	/**
	 * Reads and parses template file
	 * 
	 * @return	bool
	 **/
	function _parse()
	{
		if(is_null($this->contents))
			$this->contents = new SifterElement($this, '', '', $this->embed_flag, $this->nobreak_flag);

		if(!($this->fp = @fopen($this->template_file, 'r')))
		{
			print(SIFTER_PACKAGE.": Cannot open file '{$this->template_file}'.\n");
			return false;
		}

		if(!$this->contents->_parse())
		{
			fclose($this->fp);

			if(is_null($this->parent))
			{
				print(SIFTER_PACKAGE.": Error(s) occurred while parsing file '{$this->template_file}'.\n");
				print(SIFTER_PACKAGE.": ".$this->_get_reading_line()." lines have been read.\n");
			}
			return false;
		}

		fclose($this->fp);
		return true;
	}

	/**
	 * Applys template and displays
	 * 
	 * @return	string
	 * @param	array	$replace  Array of replacement
	 **/
	function _display(&$replace)
	{
		return $this->contents->_display($replace);
	}

	/**
	 * Displays template structure as a tree
	 * 
	 * @return	bool
	 * @param	int		$max_length  Number of characters to display text
	 * @param	string	$tabs        Tab characters
	 **/
	function _display_tree($max_length=20, $tabs='')
	{
		return $this->contents->_display_tree($max_length, $tabs);
	}

	/**
	 * Displays syntax error
	 * 
	 * @param	int		$script_line  Line number in this script
	 * @param	int		$line         Line number in currently reading file
	 * @param	string	$error        Error string
	 **/
	function _raise_error($script_line=0, $line=0, $error='')
	{
		$file = $this->_get_template_file();
		$line = ($line? $line: $this->_get_reading_line());
		$error = ($error? $error: 'Syntax error');
		print(SIFTER_PACKAGE);
		if(defined('SIFTER_DEBUG'))
			print($script_line? "($script_line)": "");
		print(": $error in $file on line $line.\n");
	}
}


/**
 * Template control class
 * 
 * @package	Sifter
 **/
class Sifter
{
	//////// Members
	/**
	 * Holds child objects
	 * 
	 * @var	object
	 **/
	var $contents = null;

	/**
	 * Capture result flag
	 * 
	 * @var	bool
	 **/
	var $capture_result = 0;

	/**
	 * Result
	 * 
	 * @var	string
	 **/
	var $result = '';

	/**
	 * Buffer size in bytes
	 * 
	 * @var	int
	 **/
	var $buffer_size = 2048;

	/**
	 * Holds replacements
	 * 
	 * @var	array
	 **/
	var $replace_vars = array();

	//////// Constructor
	/**
	 * Creates new Sifter object
	 * 
	 * @return	bool
	 * @param	int		$size  Buffer size in bytes
	 **/
	function Sifter($size=null)
	{
		if(!is_null($size))
			$this->buffer_size = $size;

		return true;
	}

	//////// Methods
	/**
	 * Returns if does capture result
	 * 
	 * @return	bool
	 **/
	function _does_capture_result()
	{
		return $this->capture_result;
	}

	/**
	 * Appends result
	 * 
	 * @param	$str  String
	 **/
	function _append_result($str)
	{
		$this->result .= $str;
	}

	/**
	 * Returns buffer size in bytes
	 * 
	 * @return	resource	Buffer size in bytes
	 **/
	function _get_buffer_size()
	{
		return $this->buffer_size;
	}

	/**
	 * Returns replacement specified by name
	 * 
	 * @return	string	Replacement
	 * @param	string	$name  Name of variable
	 **/
	function _get_var($name)
	{
		return $this->replace_vars[$name];
	}

	/**
	 * Reads and parses template file
	 * 
	 * @return	bool
	 * @param	string	$template_file  Path to template file
	 **/
	function _parse($template_file)
	{
		if(is_null($this->contents))
			$this->contents = new SifterTemplate($this, $template_file);
		else
			$this->contents->_set_template_file($template_file);

		return $this->contents->_parse();
	}

	/**
	 * Set loop count value
	 * 
	 * @param	array	$replace  Array of replacement
	 * 
	 **/
	function _set_loop_count(&$replace)
	{
		if(!is_array($replace)) return;

		reset($replace);
		while(list($key) = each($replace))
		{
			if(is_array($replace[$key]))
			{
				$replace['#'.$key.'_count'] = count($replace[$key]);
				for($i=0; $i<count($replace[$key]); $i++)
					$this->_set_loop_count($replace[$key][$i]);
			}
		}
	}

	/**
	 * Specifies control tag characters
	 * 
	 * @param	string	$begin   Control tag characters (begin)
	 * @param	string	$end     Control tag characters (end)
	 * @param	bool	$escape  If this parameter is true, meta characters will be escaped
	 **/
	function set_control_tag($begin, $end, $escape=true)
	{
		global $SIFTER_CONTROL_TAG_BGN, $SIFTER_CONTROL_TAG_END, $SIFTER_CONTROL_PATTERN;

		if($escape)
		{
			$begin = quotemeta($begin);
			$end   = quotemeta($end  );
		}

		$SIFTER_CONTROL_TAG_BGN = $begin;
		$SIFTER_CONTROL_TAG_END = $end  ;
		$SIFTER_CONTROL_PATTERN = '^(.*?)('.$begin.SIFTER_CONTROL_EXPRESSION.$end.')(.*)$';
	}

	/**
	 * Specifies replace tag characters
	 * 
	 * @param	string	$begin   Replace tag characters (begin)
	 * @param	string	$end     Replace tag characters (end)
	 * @param	bool	$escape  If this parameter is true, meta characters are escaped
	 **/
	function set_replace_tag($begin, $end, $escape=true)
	{
		global $SIFTER_REPLACE_TAG_BGN, $SIFTER_REPLACE_TAG_END, $SIFTER_REPLACE_PATTERN;

		if($escape)
		{
			$begin = quotemeta($begin);
			$end   = quotemeta($end  );
		}

		$SIFTER_REPLACE_TAG_BGN = $begin;
		$SIFTER_REPLACE_TAG_END = $end  ;
		$SIFTER_REPLACE_PATTERN = $begin.SIFTER_REPLACE_EXPRESSION.$end;
	}

	/**
	 * Sets up replacements
	 * 
	 * @param	string	$name          Name of variable
	 * @param	mixed	$value         Array or string
	 * @param	bool	$convert_html  If this parameter is true, HTML entities are converted
	 **/
	function set_var($name, $value, $convert_html=true)
	{
		if($convert_html)
			Sifter::_convert_html_entities($value);

		$this->replace_vars[$name] = $value;
	}

	/**
	 * Append loop variable
	 * 
	 * @param	string	$name          Name of variable
	 * @param	mixed	$value         Array or string
	 * @param	bool	$convert_html  If this parameter is true, HTML entities are converted
	 **/
	function append_var($name, $value, $convert_html=true)
	{
		if(!is_array($this->replace_vars[$name]))
			return;

		if($convert_html)
			Sifter::_convert_html_entities($value);

		array_push($this->replace_vars[$name], $value);
	}

	/**
	 * Displays content
	 * 
	 * @return	bool
	 * @param	string	$template_file   Path to template file
	 * @param	bool	$capture_result  If this parameter is true, does not display but returns string
	 **/
	function display($template_file, $capture_result=false)
	{
		$this->capture_result = $capture_result;

		$this->contents = null;
		$this->result = '';

		if($this->_parse($template_file))
		{
			if(!is_null($this->contents))
			{
				$this->_set_loop_count($this->replace_vars);
				if($this->contents->_display($this->replace_vars))
					return ($this->_does_capture_result()? $this->result: true);
			}
		}

		return false;
	}

	/**
	 * Displays template structure as a tree
	 * 
	 * @return	bool
	 * @param	string	$template_file  Path to template file
	 * @param	int		$max_length     Number of characters to display text
	 **/
	function display_tree($template_file, $max_length=20)
	{
		$this->contents = null;
		$this->result = '';

		if($this->_parse($template_file))
		{
			if(!is_null($this->contents))
				return $this->contents->_display_tree($max_length, '');
		}

		return false;
	}

	//////// Static methods
	/**
	 * Check condition string
	 * 
	 * @return	mixed	
	 * @param	string	$condition  Condition string
	 **/
	function _check_condition($condition)
	{
		global $SIFTER_REPLACE_PATTERN;

		$elem1 = $SIFTER_REPLACE_PATTERN;
		$elem2 = SIFTER_DECIMAL_EXPRESSION;
		$elem3 = '\'(?:[^\'\\\\]|\\\\.)*\'';
		$elem4 = '\(('.$elem1.'|'.$elem3.')\s*=~\s*(\/(?:[^\/\\\\]|\\\\.)+\/[imsx]*)\)';
		$op1 = '[\-~!]';
		$op2 = '[+\-*\/%]|\.|&|\||\^|<<|>>';
		$op3 = '===?|!==?|<>|>=?|<=?';
		$op4 = 'and|or|xor|&&|\|\|';

		if(preg_replace('/'.implode('|', array($elem1, $elem2, $elem3, $elem4, $op3, $op4, $op1, $op2)).'|[()]|\s/i', '', $condition))
		{
			return false;
		}
		else
		{
			$condition = preg_replace(
				'/('.$elem3.')/e', 'Sifter::_escape_replace_tags("$1")', $condition
			);
			$condition = preg_replace(
				'/'.$elem4.'/e', "'preg_match(\''.Sifter::_escape_replace_tags(\"\$6\").'\',\$1)'", $condition
			);
			$condition = preg_replace(
				'/'.$elem1.'/', '$replace[\'$1\']', $condition
			);

			return Sifter::_unescape_replace_tags($condition);
		}
	}

	/**
	 * Escape replace tags
	 * 
	 * @return	string	String that includes escaped replace tags
	 * @param	string	$str  Source string
	 **/
	function _escape_replace_tags($str)
	{
		global $SIFTER_REPLACE_TAG_BGN, $SIFTER_REPLACE_TAG_END;

		return preg_replace(
			'/('.$SIFTER_REPLACE_TAG_BGN.')(\\\\*?'.SIFTER_REPLACE_EXPRESSION.$SIFTER_REPLACE_TAG_END.')/', 
			'$1\\\\$2', 
			preg_replace('/\\\\\'/', '\'', $str)
		);
	}

	/**
	 * Unescape replace tags
	 * 
	 * @return	string	String that includes unescaped replace tags
	 * @param	string	$str  Source string
	 **/
	function _unescape_replace_tags($str)
	{
		global $SIFTER_REPLACE_TAG_BGN, $SIFTER_REPLACE_TAG_END;

		return preg_replace(
			'/('.$SIFTER_REPLACE_TAG_BGN.')\\\\(.+?'.$SIFTER_REPLACE_TAG_END.')/', '$1$2', $str
		);
	}

	/**
	 * Extracts attribute from tag
	 * 
	 * @return	string	Value of attribute
	 * @param	string	$tag   Tag
	 * @param	string	$name  Name of attribute to extract
	 **/
	function _get_attribute($tag, $name)
	{
		if(preg_match('/\b'.$name.'=(\'|"|\b)([^\1]*?)\1(?:\s|\/?>)/is', $tag, $matches))
			return $matches[2];

		return null;
	}

	/**
	 * Sets attribute into tag
	 * 
	 * @return	string	Tag set attribute
	 * @param	string	$tag      Tag
	 * @param	string	$name     Name of attribute to set
	 * @param	string	$value    Value of attribute to set
	 * @param	bool	$verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
	 **/
	function _set_attribute($tag, $name, $value, $verbose=true)
	{
		$pattern = '/\b'.$name.'=(\'|"|\b)[^\1]*?\1(\s|\/?>)/is';
		$attr = $name.($verbose? '="'.preg_replace('/([$\\\\\\\\])/', '\\\\$1', $value).'"': '');
		if(preg_match($pattern, $tag))
			$ret = preg_replace($pattern, $attr.'$2', $tag);
		else
			$ret = preg_replace('/<([^\/]+?)(\s*\/?)>/s', '<$1 '.$attr.'$2>', $tag, 1);

		return $ret;
	}

	/**
	 * Extracts id or name attribute from tag
	 * 
	 * @return	string	Value of id or name attribute
	 * @param	string	$tag  Tag
	 **/
	function _get_element_id($tag)
	{
		if(is_null($ret = Sifter::_get_attribute($tag, 'id')))
			$ret = Sifter::_get_attribute($tag, 'name');

		return $ret;
	}

	/**
	 * Called by function _embed_values()
	 * 
	 * @return	string	Value embedded string
	 * @param	string	$str      Source string
	 * @param	array	$values   Array of values to embed
	 * @param	bool	$verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
	 **/
	function _embed_values_callback($str, &$values, $verbose)
	{
		global $SIFTER_SELECT_NAME;

		$str = str_replace('\\"', '"', $str);

		if(preg_match('/^<(\/?.+?)\b/', $str, $matches))
			$element = $matches[1];

		if(strcasecmp($element, 'input') == 0)
		{
			$name = Sifter::_get_element_id($str);
			if(isset($values[$name]))
			{
				$type = Sifter::_get_attribute($str, 'type');
				if(strcasecmp($type, 'radio') == 0 || strcasecmp($type, 'checkbox') == 0)
				{
					if(Sifter::_get_attribute($str, 'value') == $values[$name])
						$str = Sifter::_set_attribute($str, 'checked', 'checked', $verbose);
					else
						$str = preg_replace('/(<input.*)\s+checked(?:=(\"|\'|\b)checked\2)?(\s*\/?>)/is', '$1$3', $str, 1);
				}
				else
				{
					$str = Sifter::_set_attribute($str, 'value', $values[$name]);
				}
			}
		}
		else if(strcasecmp($element, 'textarea') == 0)
		{
			$name = Sifter::_get_element_id($str);
			if(isset($values[$name]))
			{
				if(preg_match('/(<textarea\b.*?>).*?(<\/textarea>)/is', $str, $matches))
					$str = $matches[1].$values[$name].$matches[2];
			}
		}
		else if(strcasecmp($element, 'select') == 0)
		{
			if(!$SIFTER_SELECT_NAME)
				$SIFTER_SELECT_NAME = preg_replace('/\[\]$/', '', Sifter::_get_element_id($str), 1);
		}
		else if(strcasecmp($element, '/select') == 0)
		{
			$SIFTER_SELECT_NAME = '';
		}
		else if(strcasecmp($element, 'option') == 0)
		{
			if($SIFTER_SELECT_NAME && isset($values[$SIFTER_SELECT_NAME]))
			{
				if(is_null($value = Sifter::_get_attribute($str, 'value')))
				{
					if(preg_match('/<option\b.*?>(.*?)(?:<\/option>|[\r\n])/i', $str, $matches))
						$value = $matches[1];
				}

				if(
					(is_array($values[$SIFTER_SELECT_NAME]) && in_array($value, $values[$SIFTER_SELECT_NAME])) || 
					$value == $values[$SIFTER_SELECT_NAME]
				)
					$str = Sifter::_set_attribute($str, 'selected', 'selected', $verbose);
				else
				{
					$str = preg_replace('/(<option.*)\s+selected(?:=(\"|\'|\b)selected\2)?(\s*\/?>)/is', '$1$3', $str, 1);
				}
			}
		}

		return $str;
	}

	/**
	 * Embed value into element of form
	 * 
	 * @return	string	Value embedded string
	 * @param	string	$str      Source string
	 * @param	array	$values   Array of values to embed
	 * @param	bool	$verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
	 **/
	function _embed_values(&$str, &$values, $verbose=true)
	{
		$str = preg_replace(
			'/('.SIFTER_EMBED_EXPRESSION.')/eis', 
			'Sifter::_embed_values_callback(\'$1\',$values,$verbose)', 
			$str
		);
	}

	/**
	 * Convert HTML entities
	 * 
	 * @param	mixed	$value  String or array to convert
	 **/
	function _convert_html_entities(&$value)
	{
		if(is_array($value))
		{
			foreach(array_keys($value) as $key)
				Sifter::_convert_html_entities($value[$key]);
		}
		else if(is_string($value))
		{
			$value = htmlspecialchars($value);
		}
	}

	/**
	 * Called by function format()
	 * 
	 * @return	string	Formatted value
	 * @param	string	$value    Value
	 * @param	string	$comma    If this parameter is set, numeric value will be converted to comma formatted value
	 * @param	string	$options  Options
	 **/
	function _format_callback($value, $comma='', $options='')
	{
		if($comma != '')
			$value = number_format($value, substr($comma, 1));
		if($options != '')
		{
			if(strpos($options, 'b') !== false)
			{
				// Convert linebreaks to "<br />"
				$value = nl2br($value);
			}
			if(strpos($options, 'q') !== false)
			{
				// Escape quotes, backslashes and linebreaks
				$value = preg_replace("/([\'\"\\\\]|&quot;)/", "\\\\$1", $value);
				$value = addcslashes($value, "\r\n");
			}
		}

		return $value;
	}

	/**
	 * Format string
	 * 
	 * @return	string	Formatted string
	 * @param	string	$format   Format string
	 * @param	array	$replace  Array of replacement
	 **/
	function format($format, &$replace)
	{
		global $SIFTER_REPLACE_PATTERN;
		return preg_replace(
			'/'.$SIFTER_REPLACE_PATTERN.'/e', 
			'Sifter::_format_callback((isset($replace[\'$1\'])? $replace[\'$1\']: \'\')$2,\'$3\',\'$4\')', $format
		);
	}
}

?>

package Sifter;

use 5.005;
use strict;

##
# Sifter - a simple and functional template engine
# 
# $Id$
# 
# @package		Sifter
# @version		1.1.6
# @author		Masayuki Iwai <miyabi@mybdesign.com>
# @copyright	Copyright &copy; 2005-2009 Masayuki Iwai all rights reserved.
# @license		BSD license
##


=head1 NAME

Sifter - a simple and functional template engine

=head1 SYNOPSIS

Example code:

  use Sifter;
  $template = Sifter->new;
  $template->set_var('foo', 'bar');
  $template->set_var('condition', 'true');
  $template->set_var('array', [{'loop'=>1}, {'loop'=>2}, {'loop'=>3}]);
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

=head1 DESCRIPTION

This module is a simple and functional template engine.

=head1 SEE ALSO

http://www.mybdesign.com/sifter/

=head1 COPYRIGHT AND LICENSE

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

=cut


################ Global variables
use vars qw(@ISA $VERSION $PACKAGE);
use vars qw(
	$SIFTER_AVAILABLE_CONTROLS $SIFTER_CONTROL_EXPRESSION $SIFTER_DECIMAL_EXPRESSION
	$SIFTER_REPLACE_EXPRESSION $SIFTER_EMBED_EXPRESSION $SIFTER_CONDITIONAL_EXPRESSION
	$SIFTER_CONTROL_TAG_BGN $SIFTER_CONTROL_TAG_END $SIFTER_CONTROL_PATTERN
	$SIFTER_REPLACE_TAG_BGN $SIFTER_REPLACE_TAG_END $SIFTER_REPLACE_PATTERN
	$SIFTER_SELECT_NAME
	$SIFTER_DEBUG
);

@ISA = qw();
$VERSION = '1.0106';
$PACKAGE = 'Sifter';

$SIFTER_AVAILABLE_CONTROLS = 'LOOP|FOR|IF|ELSE|EMBED|NOBREAK|LITERAL|INCLUDE|\?';
$SIFTER_CONTROL_EXPRESSION = '((END_)?('.$SIFTER_AVAILABLE_CONTROLS.'))(?:\((.*?)\))?';
$SIFTER_DECIMAL_EXPRESSION = '-?(?:\d*?\.\d+|\d+\.?)';
$SIFTER_REPLACE_EXPRESSION = '(#?[A-Za-z_]\w*?)(\s*[\+\-\*\/%]\s*'.$SIFTER_DECIMAL_EXPRESSION.')?(,\d*)?((?:\:|\/)\w+)?';
$SIFTER_EMBED_EXPRESSION = '<(?:input|\/?select)\b.*?>|<option\b.*?>.*?(?:<\/option>|[\r\n])|<textarea\b.*?>.*?<\/textarea>';
$SIFTER_CONDITIONAL_EXPRESSION = '((?:[^\'\?]+|(?:\'(?:\\\\.|[^\'])*?\'))+)\?\s*((?:\\\\.|[^:])*)\s*:\s*(.*)';

$SIFTER_CONTROL_TAG_BGN = '<!--@';
$SIFTER_CONTROL_TAG_END = '-->';
$SIFTER_CONTROL_PATTERN = '^((.*?)('.$SIFTER_CONTROL_TAG_BGN.$SIFTER_CONTROL_EXPRESSION.$SIFTER_CONTROL_TAG_END.')(.*))$';
$SIFTER_REPLACE_TAG_BGN = '\{';
$SIFTER_REPLACE_TAG_END = '\}';
$SIFTER_REPLACE_PATTERN = $SIFTER_REPLACE_TAG_BGN.$SIFTER_REPLACE_EXPRESSION.$SIFTER_REPLACE_TAG_END;

$SIFTER_SELECT_NAME = '';
$SIFTER_DEBUG = 0;


################ Classes
##
# Template element class
# 
# @package	Sifter
##
package Sifter::Element;

######## Constructor
##
# Creates new Sifter::Element object
# 
# @return	object
# @param	object	$parent        Parent object
# @param	string	$type          Type of this object
# @param	string	$param         Parameter string
# @param	int		$embed_flag    Embed flag
# @param	int		$nobreak_flag  No-break flag
##
sub new#(&$parent, $type='', $param='', $embed_flag=0, $nobreak_flag=0)
{
	my $class = shift;
	my $this = {
		######## Members
		##
		# Holds top level object
		# 
		# @var	object
		##
		top=>undef, 

		##
		# Holds template object
		# 
		# @var	object
		##
		template=>undef, 

		##
		# Holds parent object
		# 
		# @var	object
		##
		parent=>undef, 

		##
		# Type of this object
		# 
		# @var	string
		##
		type=>'', 

		##
		# Parameter string
		# 
		# @var	string
		##
		param=>'', 

		##
		# Holds child objects
		# 
		# @var	array
		##
		contents=>[], 

		##
		# Count child objects
		# 
		# @var	int
		##
		content_index=>-1, 

		##
		# Embed flag
		# 
		# @var	int
		##
		embed_flag=>0, 

		##
		# No-break flag
		# 
		# @var	int
		##
		nobreak_flag=>0, 

		##
		# Result of previous evaluation of condition
		# 
		# @var	bool
		##
		prev_eval_result=>1, 
	};

	my $parent = shift;
	my $type = shift;
	my $param = shift;
	my $embed_flag = shift;
	my $nobreak_flag = shift;

	return undef if(!defined($parent));

	$type = '' if(!defined($type));
	$param = '' if(!defined($param));

	$this->{top} = (defined($parent->_get_top())? $parent->_get_top(): $parent);
	$this->{template} = (defined($parent->_get_template())? $parent->_get_template(): $parent);

	$this->{parent} = $parent;
	$this->{type} = $type;
	$this->{param} = $param;

	$this->{embed_flag} = (defined($embed_flag)? $embed_flag: 0);
	$this->{nobreak_flag} = (defined($nobreak_flag)? $nobreak_flag: 0);

	return bless($this, $class);
}

######## Methods
##
# Returns reference to top level object
# 
# @return	object	Reference to top level object
##
sub _get_top#()
{
	my $this = shift;

	return $this->{top};
}

##
# Returns reference to template object
# 
# @return	object	Reference to template object
##
sub _get_template#()
{
	my $this = shift;

	return $this->{template};
}

##
# Returns reference to parent object
# 
# @return	object	Reference to parent object
##
sub _get_parent#()
{
	my $this = shift;

	return $this->{parent};
}

##
# Reads and parses template file
# 
# @return	bool
##
sub _parse#()
{
	my $this = shift;

	my $buf = $this->{template}->_get_buffer();
	return undef if(!defined($buf));

	my $literal = ($this->{type} eq 'LITERAL');
	my ($i, $temp, @matches);

	$i = 0;
	while(${$buf} ne '' || $this->{template}->_read_line())
	{
		if(!(@matches = (${$buf} =~ /$Sifter::SIFTER_CONTROL_PATTERN/s)))
		{
			# Text
			$this->_append_text(${$buf});
			${$buf} = '';
			next;
		}

		if($literal && $matches[3] ne 'END_LITERAL')
		{
			# LITERAL block
			$this->_append_text($matches[1].$matches[2]);
			${$buf} = $matches[7];
			$this->{template}->_set_preserve_spaces_flag(1);
			next;
		}

		if(defined($matches[1]) && defined($matches[7]) && ($matches[1].$matches[7]) =~ /[^\s]/)
		{
			$this->_append_text($matches[1]);
			${$buf} = $matches[7];
			$this->{template}->_set_preserve_spaces_flag(1);
		}
		elsif($this->{template}->_get_preserve_spaces_flag() || $matches[3] eq 'END_NOBREAK')
		{
			$matches[1] =~ s/[^\r\n]//g;
			$this->_append_text($matches[1]);
			(${$buf} = $matches[7]) =~ s/[^\r\n]//g;
		}
		else
		{
			${$buf} = '';
		}

		my $type = (defined($matches[5])? $matches[5]: '');
		(my $param = (defined($matches[6])? $matches[6]: '')) =~ s/^\s+|\s+$//;

		if($matches[4])
		{
			# End of block
			if(
				$param eq '' && 
				($this->{type} eq $type || ($this->{type} eq 'ELSE' && ($type eq 'IF' || $type eq 'LOOP')))
			)
			{
				return 1;
			}
			else
			{
				$this->{template}->_raise_error(__LINE__);
				return undef;
			}
		}

		if(($type eq 'LOOP' || $type eq 'FOR') && $param ne '')
		{
			# LOOP, FOR block
			if(!$this->_append_element($type, $param))
			{
				return undef;
			}
		}
		elsif($type eq 'IF' && $param ne '')
		{
			# IF block
			if(!defined($param = Sifter::_check_condition($param)))
			{
				return undef;
			}
			if(!$this->_append_element($type, $param))
			{
				return undef;
			}
		}
		elsif($type eq 'ELSE')
		{
			# ELSE block
			if($this->{type} eq 'LOOP' && $param eq '')
			{
				if(!$this->{parent}->_append_element($type, $param))
				{
					return undef;
				}

				last;
			}
			elsif($this->{type} eq 'IF' || $this->{type} eq 'ELSE')
			{
				if($param ne '' && !defined($param = Sifter::_check_condition($param)))
				{
					$this->{template}->_raise_error(__LINE__);
					return undef;
				}
				if(!$this->{parent}->_append_element($type, $param))
				{
					return undef;
				}

				last;
			}
			else
			{
				$this->{template}->_raise_error(__LINE__);
				return undef;
			}
		}
		elsif($type eq '?' && $param ne '')
		{
			# ?
			@matches = ($param =~ /$Sifter::SIFTER_CONDITIONAL_EXPRESSION/);
			if($#matches < 0 || !defined($matches[0] = Sifter::_check_condition($matches[0])))
			{
				$this->{template}->_raise_error(__LINE__);
				return undef;
			}
			$matches[1] =~ s/\\(.)/$1/g;
			$matches[2] =~ s/\\(.)/$1/g;
			if(!$this->_append_element('IF', $matches[0], 1, $matches[1]))
			{
				return undef;
			}
			if(!$this->_append_element('ELSE', '', 1, $matches[2]))
			{
				return undef;
			}
		}
		elsif($type eq 'EMBED')
		{
			# EMBED block
			$param =~ tr/A-Z/a-z/;
			if($param eq '' || $param eq 'xml' || $param eq 'html')
			{
				if(!$this->_append_element($type, ($param eq 'html')? 1: 3))
				{
					return undef;
				}
			}
			else
			{
				$this->{template}->_raise_error(__LINE__);
				return undef;
			}
		}
		elsif(($type eq 'NOBREAK' || $type eq 'LITERAL') && $param eq '')
		{
			# NOBREAK, LITERAL block
			if(!$this->_append_element($type, ''))
			{
				return undef;
			}
		}
		elsif($type eq 'INCLUDE' && $param ne '')
		{
			# INCLUDE
			if(!$this->_append_template($param))
			{
				return undef;
			}
		}
		else
		{
			# Syntax error
			$this->{template}->_raise_error(__LINE__);
			return undef;
		}
	}

	return 1;
}

##
# Appends string to this object
# 
# @return	bool
# @param	string	$str  String
##
sub _append_text#($str)
{
	my $this = shift;
	my $str = shift;

	if($str ne '')
	{
		$this->{content_index}++ if(!@{$this->{contents}} || ref($this->{contents}[$this->{content_index}]));
		$this->{contents}[$this->{content_index}] .= $str;
	}
}

##
# Appends block to this object
# 
# @return	bool
# @param	string	$type     Type of this object
# @param	string	$param    Paramenter string
# @param	bool	$noparse  If this parameter is true, skips parsing added element
# @param	string	$str      Additional string
##
sub _append_element#($type, $param, $noparse=false, $str='')
{
	my $this = shift;
	my $type = shift;
	my $param = shift;
	my $noparse = shift;
	my $str = shift;

	if(
		$this->{contents}[++$this->{content_index}] = Sifter::Element->new(
			$this, $type, $param, 
			(($type eq 'EMBED'  )? $param: $this->{embed_flag  }), 
			(($type eq 'NOBREAK')? 1     : $this->{nobreak_flag})
		)
	)
	{
		if(!$noparse)
		{
			if(!$this->{contents}[$this->{content_index}]->_parse())
			{
				return undef;
			}
		}

		$this->{contents}[$this->{content_index}]->_append_text($str) if(defined($str));
		return 1;
	}

	return undef;
}

##
# Appends block to this object
# 
# @return	bool
# @param	string	$template_file  Path to template file
##
sub _append_template#($template_file)
{
	my $this = shift;
	my $template_file = shift;

	$template_file = $this->{template}->_get_dir_path().'/'.$template_file if(substr($template_file, 0, 1) ne '/');
	if($this->{template}->_is_recursive($template_file))
	{
		$this->{template}->_raise_error(__LINE__, 0, "'$template_file' is included recursively");
		return undef;
	}

	if(
		$this->{contents}[++$this->{content_index}] = Sifter::Template->new(
			$this, $template_file, $this->{embed_flag}, $this->{nobreak_flag}
		)
	)
	{
		return $this->{contents}[$this->{content_index}]->_parse();
	}

	return undef;
}

##
# Displays content
# 
# @return	bool
# @param	array	$replace  Array of replacement
##
sub _display_content#(&$replace)
{
	my $this = shift;
	my $replace = shift;

	my $literal = ($this->{type} eq 'LITERAL');
	my $content;

	foreach(@{$this->{contents}})
	{
		$content = $_;
		if(ref($content))
		{
			return undef if(!$content->_display($replace));
		}
		else
		{
			# Text
			if(!$literal)
			{
				$content =~ s/[\r\n]//g if($this->{nobreak_flag});
				$content = Sifter::format($content, $replace);
				Sifter::_embed_values(\$content, $replace, ($this->{embed_flag}&2)? 1: 0) if($this->{embed_flag});
			}

			if($this->{top}->_does_capture_result())
			{
				$this->{top}->_append_result($content);
			}
			else
			{
				print($content);
			}
		}
	}

	return 1;
}

##
# Applys template and displays
# 
# @return	bool
# @param	array	$replace  Array of replacement
##
sub _display#(&$replace)
{
	my $this = shift;
	my $replace = shift;

	my ($param, $count, $i, $j, $k, $l, %temp, $key, $value);

	if($this->{type} eq 'LOOP')
	{
		# LOOP block
		if(ref(${$replace}{$this->{param}}) ne 'ARRAY' || $#{${$replace}{$this->{param}}} < 0)
		{
			$this->{parent}->{prev_eval_result} = 0;
			return 1;
		}

		$this->{parent}->{prev_eval_result} = 1;

		$i = 0;
		foreach(@{${$replace}{$this->{param}}})
		{
			%temp = ((ref($_) eq 'HASH')? %{$_}: ('#value'=>$_));

			while(($key, $value) = each(%{$replace}))
			{
				$temp{$key} = $value if(!defined($temp{$key}));
			}
			$temp{'#'.$this->{param}.'_index'} = $i;

			return undef if(!$this->_display_content(\%temp));

			$i++;
		}
	}
	elsif($this->{type} eq 'FOR')
	{
		# FOR block
		if(($param = Sifter::format($this->{param}, $replace)) =~ /^(-?\d+),\s*(-?\d+)(?:,\s*(-?\d+))?$/)
		{
			$j = $1;
			$k = $2;
			$l = ($3? $3: (($j<=$k)? 1: -1));
			%temp = %{$replace};
			for($i=$j; ($l>0 && $i<=$k) || ($l<0 && $i>=$k); $i+=$l)
			{
				$temp{'#value'} = $i;
				return undef if(!$this->_display_content(\%temp));
			}
		}
	}
	elsif($this->{type} eq 'IF' || ($this->{type} eq 'ELSE' && !$this->{parent}->{prev_eval_result}))
	{
		# IF, ELSE block
		if($this->{param} eq '' || eval('return ('.$this->{param}.');'))
		{
			return undef if(!$this->_display_content($replace));
			$this->{parent}->{prev_eval_result} = 1;
		}
		else
		{
			$this->{parent}->{prev_eval_result} = 0;
		}
	}
	elsif($this->{type} ne 'ELSE')
	{
		# Other types of block
		return undef if(!$this->_display_content($replace));
	}

	return 1;
}

##
# Displays template structure as a tree
# 
# @param	int		$max_length  Number of characters to display text
# @param	string	$tabs        Tab characters
##
sub _display_tree#($max_length=20, $tabs='')
{
	my $this = shift;
	my $max_length = shift;
	my $tabs = shift;

	$max_length = 20 if(!defined($max_length));
	$tabs = '' if(!defined($tabs));

	my $content;

	if($this->{type})
	{
		print($tabs."[".$this->{type}.(($this->{param} ne '')? '('.$this->{param}.')': '')."]\n");
	}
	else
	{
		print($tabs."[TEMPLATE:".$this->{template}->_get_template_file()."]\n");
	}

	foreach $content (@{$this->{contents}})
	{
		if(ref($content) eq 'Sifter::Element')
		{
			$content->_display_tree($max_length, $tabs."\t");
		}
		elsif(ref($content) eq 'Sifter::Template')
		{
			$content->_display_tree($max_length, $tabs."\t");
		}
		else
		{
			$content =~ s/[\r\n]/ /g;
			print($tabs."\t[TEXT:".substr($content, 0, $max_length)."]\n");
		}
	}
}


##
# Template control class
# 
# @package	Sifter
##
package Sifter::Template;

######## Constructor
##
# Creates new Sifter::Template object
# 
# @return	object
# @param	object	$parent         Parent object
# @param	string	$template_file  Path to template file
# @param	int		$embed_flag     Embed flag
# @param	int		$nobreak_flag   No-break flag
##
sub new#(&$parent, $template_file='', $embed_flag=0, $nobreak_flag=0)
{
	my $class = shift;
	my $this = {
		######## Members
		##
		# Holds top level object
		# 
		# @var	object
		##
		top=>undef, 

		##
		# Holds template object
		# 
		# @var	object
		##
		template=>undef, 

		##
		# Holds parent object
		# 
		# @var	object
		##
		parent=>undef, 

		##
		# Holds child objects
		# 
		# @var	object
		##
		contents=>undef, 

		##
		# Path to template file
		# 
		# @var	string
		##
		template_file=>'', 

		##
		# Path to directory includes template file
		# 
		# @var	string
		##
		dir_path=>'', 

		##
		# File pointer of template file
		# 
		# @var	resource
		##
		fp=>undef, 

		##
		# Buffer
		# 
		# @var	resource
		##
		buffer=>'', 

		##
		# Line number in currently reading file
		# 
		# @var	int
		##
		reading_line=>0, 

		##
		# Flag of preserving spaces in the line that includes control tags only
		# 
		# @var	bool
		##
		preserve_spaces=>0, 

		##
		# Embed flag
		# 
		# @var	int
		##
		embed_flag=>0, 

		##
		# No-break flag
		# 
		# @var	int
		##
		nobreak_flag=>0, 
	};

	my $parent = shift;
	my $template_file = shift;
	my $embed_flag = shift;
	my $nobreak_flag = shift;

	$template_file = '' if(!defined($template_file));

	return undef if(!defined($parent));

	if(ref($parent) eq 'Sifter' || !defined($parent->_get_top()))
	{
		$this->{top} = $parent;
		$this->{parent} = undef;
	}
	else
	{
		$this->{top} = $parent->_get_top();
		$this->{parent} = $parent;
	}

	$this->{template_file} = $template_file;
	$this->{dir_path} = (($template_file =~ /^(.*)\//)? $1: '.');

	$this->{embed_flag} = (defined($embed_flag)? $embed_flag: 0);
	$this->{nobreak_flag} = (defined($nobreak_flag)? $nobreak_flag: 0);

	return bless($this, $class);
}

######## Methods
##
# Returns reference to top level object
# 
# @return	object	Reference to top level object
##
sub _get_top#()
{
	my $this = shift;

	return $this->{top};
}

##
# Returns reference to template object
# 
# @return	object	Reference to template object
##
sub _get_template#()
{
	my $this = shift;

	return $this->{template};
}

##
# Returns reference to parent object
# 
# @return	object	Reference to parent object
##
sub _get_parent#()
{
	my $this = shift;

	return $this->{parent};
}

##
# Specifies path to template file
# 
# @param	string	$template_file  Path to template file
##
sub _set_template_file#($template_file)
{
	my $this = shift;
	my $template_file = shift;

	$this->{template_file} = $template_file;
	$this->_set_dir_path($template_file);
}

##
# Returns path to template file
# 
# @return	string	Path to template file
##
sub _get_template_file#()
{
	my $this = shift;

	return $this->{template_file};
}

##
# Specifies path to directory includes template file
# 
# @param	string	$template_file  Path to template file
##
sub _set_dir_path#($template_file)
{
	my $this = shift;
	my $template_file = shift;

	$this->{dir_path} = (($template_file =~ /^(.*)\//)? $1: '.');
}

##
# Returns path to directory includes template file
# 
# @return	string	Path to directory includes template file
##
sub _get_dir_path#()
{
	my $this = shift;

	return $this->{dir_path};
}

##
# Preserves spaces in the line that includes control tags only
# 
# @param	bool	$flag  If this parameter is true, spaces in the line that includes control tags only will be preserved
##
sub _set_preserve_spaces_flag#($flag)
{
	my $this = shift;
	my $flag = shift;

	$this->{preserve_spaces} = $flag;
}

##
# Returns true if spaces in the line that includes control tags only will be 
# 
# @return	bool
##
sub _get_preserve_spaces_flag#()
{
	my $this = shift;

	return $this->{preserve_spaces};
}

##
# Returns true if specified template is included recursively
# 
# @return	bool
# @param	string	$template_file  Path to template file
##
sub _is_recursive#($template_file)
{
	my $this = shift;
	my $template_file = shift;

	return 1 if($this->{template_file} eq $template_file);
	return $this->{parent}->_get_template()->_is_recursive($template_file) if(defined($this->{parent}));
	return undef;
}

##
# Returns reference to buffer
# 
# @return	resource	Reference to buffer
##
sub _get_buffer#()
{
	my $this = shift;

	return \$this->{buffer};
}

##
# Counts up line number in currently reading file
# 
##
sub _increment_file_line#()
{
	my $this = shift;

	$this->{reading_line}++;
}

##
# Returns line number in currently reading file
# 
# @return	int	Line number in currently reading file
##
sub _get_reading_line#()
{
	my $this = shift;

	return $this->{reading_line};
}

##
# Reads template file
# 
# @return	bool
##
sub _read_line#()
{
	my $this = shift;

	my $fp = $this->{fp};
	if($fp && ($this->{buffer} = <$fp>))
	{
		$this->_increment_file_line();
		$this->_set_preserve_spaces_flag(0);
		return 1;
	}

	return undef;
}

##
# Reads and parses template file
# 
# @return	bool
##
sub _parse#()
{
	my $this = shift;

	$this->{contents} = Sifter::Element->new($this, '', '', $this->{embed_flag}, $this->{nobreak_flag}) if(!defined($this->{contents}));

	my $fp;
	local *fp;
	if(!(open(*fp, '<'.$this->{template_file})))
	{
		print("$Sifter::PACKAGE: Cannot open file '$this->{template_file}'.\n");
		return undef;
	}

	$this->{fp} = *fp;

	my $line_break = $/;
	$/ = $Sifter::LINE_BREAK if(defined($Sifter::LINE_BREAK));

	if(!$this->{contents}->_parse())
	{
		$/ = $line_break;
		close(*fp);

		if(!defined($this->{parent}))
		{
			print("$Sifter::PACKAGE: Error(s) occurred while parsing file '$this->{template_file}'.\n");
			print("$Sifter::PACKAGE: ".$this->_get_reading_line()." lines have been read.\n");
		}
		return undef;
	}

	$/ = $line_break;
	close(*fp);
	return 1;
}

##
# Applys template and displays
# 
# @return	string
# @param	array	$replace  Array of replacement
##
sub _display#(&$replace)
{
	my $this = shift;

	return $this->{contents}->_display(@_);
}

##
# Displays template structure as a tree
# 
# @return	bool
# @param	int		$max_length  Number of characters to display text
# @param	string	$tabs        Tab characters
##
sub _display_tree#($max_length=20, $tabs='')
{
	my $this = shift;

	return $this->{contents}->_display_tree(@_);
}

##
# Displays syntax error
# 
# @param	int		$script_line  Line number in this script
# @param	int		$line         Line number in currently reading file
# @param	string	$error        Error string
##
sub _raise_error#($script_line=0, $line=0, $error='')
{
	my $this = shift;
	my $script_line = shift;
	my $line = shift;
	my $error = shift;

	$script_line = 0 if(!defined($script_line));
	$line = 0 if(!defined($line));
	$error = '' if(!defined($error));

	my $file;

	$file = $this->_get_template_file();
	$line = ($line? $line: $this->_get_reading_line());
	$error = ($error? $error: 'Syntax error');
	print($Sifter::PACKAGE);
	print($script_line? "($script_line)": "") if(defined($Sifter::SIFTER_DEBUG));
	print(": $error in $file on line $line.\n");
}


##
# Template control class
# 
# @package	Sifter
##
package Sifter;

######## Constructor
##
# Creates new Sifter object
# 
# @return	bool
##
sub new#()
{
	my $class = shift;
	my $this = {
		######## Members
		##
		# Package name
		# 
		# @var	string
		##
		package=>'Sifter', 

		##
		# Holds child objects
		# 
		# @var	object
		##
		contents=>undef, 

		##
		# Capture result flag
		# 
		# @var	bool
		##
		capture_result=>0, 

		##
		# Result
		# 
		# @var	string
		##
		result=>'', 

		##
		# Holds replacements
		# 
		# @var	array
		##
		replace_vars=>{}, 
	};

	return bless($this, $class);
}

######## Methods
##
# Returns if does capture result
# 
# @return	bool
##
sub _does_capture_result#()
{
	my $this = shift;

	return $this->{capture_result};
}

##
# Appends result
# 
# @param	$str  String
##
sub _append_result#($str)
{
	my $this = shift;
	my $str = shift;

	$this->{result} .= $str;
}

##
# Returns replacement specified by name
# 
# @return	string	Replacement
# @param	string	$name  Name of variable
##
sub _get_var#($name)
{
	my $this = shift;
	my $name = shift;

	return $this->{replace_vars}{$name};
}

##
# Called by function set_var()
# 
# @param	reference	$var           Reference to variable
# @param	mixed		$value         Array or string
# @param	bool		$convert_html  If this parameter is true, HTML entities are converted
##
sub _construct_var
{
	my $this = shift;
	my $var = shift;
	my $value = shift;
	my $convert_html = shift;

	my $key;

	if(!ref($value))
	{
		$this->_convert_html_entities(\$value) if(defined($convert_html) && $convert_html);
		${$var} = $value;
	}
	elsif(ref($value) eq 'REF')
	{
		$this->_construct_var($var, ${$value}, $convert_html);
	}
	elsif(ref($value) eq 'ARRAY')
	{
		${$var} = [];
		foreach $key (0..$#{$value})
		{
			${${$var}}[$key] = undef;
			$this->_construct_var(\${${$var}}[$key], ${$value}[$key]);
		}
	}
	elsif(ref($value) eq 'HASH')
	{
		${$var} = {};
		foreach $key (keys(%{$value}))
		{
			${${$var}}{$key} = undef;
			$this->_construct_var(\${${$var}}{$key}, ${$value}{$key});
		}
	}
}

##
# Reads and parses template file
# 
# @return	bool
# @param	string	$template_file  Path to template file
##
sub _parse#($template_file)
{
	my $this = shift;
	my $template_file = shift;

	if(!defined($this->{contents}))
	{
		$this->{contents} = Sifter::Template->new($this, $template_file);
	}
	else
	{
		$this->{contents}->_set_template_file($template_file);
	}

	return $this->{contents}->_parse();
}

##
# Set loop count value
# 
# @param	array	$replace  Array of replacement
# 
##
sub _set_loop_count#(&$replace)
{
	my $this = shift;
	my $replace = shift;

	my $key;

	return if(ref($replace) ne 'HASH');

	foreach $key (keys(%{$replace}))
	{
		if(ref(${$replace}{$key}) eq 'ARRAY')
		{
			${$replace}{'#'.$key.'_count'} = $#{${$replace}{$key}} + 1;
			foreach(0..$#{${$replace}{$key}})
			{
				$this->_set_loop_count(${${$replace}{$key}}[$_]);
			}
		}
	}
}

##
# Specifies control tag characters
# 
# @param	string	$begin   Control tag characters (begin)
# @param	string	$end     Control tag characters (end)
# @param	bool	$escape  If this parameter is true, meta characters are escaped
##
sub set_control_tag#($begin, $end, $escape=true)
{
	my $this = shift;
	my $begin = shift;
	my $end = shift;
	my $escape = shift;

	$escape = 1 if(!defined($escape));

	if($escape)
	{
		$begin =~ s/([.*+?^\$\\|()\[\]])/\\$1/g;
		$end   =~ s/([.*+?^\$\\|()\[\]])/\\$1/g;
	}

	$SIFTER_CONTROL_TAG_BGN = $begin;
	$SIFTER_CONTROL_TAG_END = $end  ;
	$SIFTER_CONTROL_PATTERN = '^((.*?)('.$begin.$SIFTER_CONTROL_EXPRESSION.$end.')(.*))$';
}

##
# Specifies replace tag characters
# 
# @param	string	$begin   Replace tag characters (begin)
# @param	string	$end     Replace tag characters (end)
# @param	bool	$escape  If this parameter is true, meta characters are escaped
##
sub set_replace_tag#($begin, $end, $escape=true)
{
	my $this = shift;
	my $begin = shift;
	my $end = shift;
	my $escape = shift;

	$escape = 1 if(!defined($escape));

	if($escape)
	{
		$begin =~ s/([.*+?^\$\\|()\[\]])/\\$1/g;
		$end   =~ s/([.*+?^\$\\|()\[\]])/\\$1/g;
	}

	$SIFTER_REPLACE_TAG_BGN = $begin;
	$SIFTER_REPLACE_TAG_END = $end  ;
	$SIFTER_REPLACE_PATTERN = $begin.$SIFTER_REPLACE_EXPRESSION.$end;
}

##
# Sets up replacements
# 
# @param	string	$name          Name of variable
# @param	mixed	$value         Array or string
# @param	bool	$convert_html  If this parameter is true, HTML entities are converted
##
sub set_var#($name, $value, $convert_html=true)
{
	my $this = shift;
	my $name = shift;
	my $value = shift;
	my $convert_html = shift;

	if(!ref($value))
	{
		Sifter::_convert_html_entities(\$value) if(!defined($convert_html) || $convert_html);
		$this->{replace_vars}{$name} = $value;
	}
	elsif(ref($value) eq 'REF')
	{
		$this->set_var($name, ${$value}, $convert_html);
	}
	elsif((ref($value) eq 'ARRAY' || ref($value) eq 'HASH'))
	{
		$this->{replace_vars}{$name} = undef;
		$this->_construct_var(\$this->{replace_vars}{$name}, $value, $convert_html);
	}
}

##
# Append loop variable
# 
# @param	string	$name          Name of variable
# @param	mixed	$value         Array or string
# @param	bool	$convert_html  If this parameter is true, HTML entities are converted
##
sub append_var#($name, $value, $convert_html=true)
{
	my $this = shift;
	my $name = shift;
	my $value = shift;
	my $convert_html = shift;

	return if(ref($this->{replace_vars}{$name}) ne 'ARRAY');

	if(!ref($value))
	{
		Sifter::_convert_html_entities(\$value) if(!defined($convert_html) || $convert_html);
		push(@{$this->{replace_vars}{$name}}, $value);
	}
	elsif(ref($value) eq 'REF')
	{
		$this->append_var($name, ${$value}, $convert_html);
	}
	elsif((ref($value) eq 'ARRAY' || ref($value) eq 'HASH'))
	{
		push(@{$this->{replace_vars}{$name}}, undef);
		$this->_construct_var(\${$this->{replace_vars}{$name}}[$#{$this->{replace_vars}{$name}}], $value, $convert_html);
	}
}

##
# Displays content
# 
# @return	bool
# @param	string	$template_file   Path to template file
# @param	bool	$capture_result  If this parameter is true, does not display but returns string
##
sub display#($template_file, $capture_result=false)
{
	my $this = shift;
	my $template_file = shift;
	my $capture_result = shift;

	$this->{capture_result} = $capture_result;

	$this->{contents} = undef;
	$this->{result} = '';

	if($this->_parse($template_file))
	{
		if(defined($this->{contents}))
		{
			$this->_set_loop_count($this->{replace_vars});
			if($this->{contents}->_display($this->{replace_vars}))
			{
				return ($this->_does_capture_result()? $this->{result}: 1);
			}
		}
	}

	return undef;
}

##
# Displays template structure as a tree
# 
# @return	bool
# @param	string	$template_file  Path to template file
# @param	int		$max_length     Number of characters to display text
##
sub display_tree#($template_file, $max_length=20)
{
	my $this = shift;
	my $template_file = shift;
	my $max_length = shift;

	$this->{contents} = undef;
	$this->{result} = '';

	if($this->_parse($template_file))
	{
		if(defined($this->{contents}))
		{
			return $this->{contents}->_display_tree($max_length, '');
		}
	}

	return undef;
}

######## Static methods
##
# Check condition string
# 
# @return	string	Parsed condition
# @param	string	$condition  Condition string
##
sub _check_condition#($condition)
{
	my $condition = shift;

	my $elem1 = $SIFTER_REPLACE_PATTERN;
	my $elem2 = $SIFTER_DECIMAL_EXPRESSION;
	my $elem3 = '\'(?:[^\'\\\\]|\\\\.)*\'';
	my $elem4 = '\(('.$elem1.'|'.$elem3.')\s*=~\s*(\/(?:[^\/\\\\]|\\\\.)+\/[imsx]*)\)';
	my $op1 = '[\-~!]|not';
	my $op2 = '[+\-*\/%]|\.|&|\||\^|<<|>>';
	my $op3 = '==|!=|<=>|>=?|<=?';
	my $op3_2 = 'eq|ne|gt|ge|lt|le|cmp';
	my $op4 = 'and|or|xor|&&|\|\|';
	my %ops = ('=='=>'eq', '!='=>'ne', '<=>'=>'cmp', '>'=>'gt', '>='=>'ge', '<'=>'lt', '<='=>'le');
	my $temp;

	($temp = $condition) =~ s/$elem1|$elem2|$elem3|$elem4|$op3|$op3_2|$op4|$op1|$op2|[()]|\s//gi;
	if($temp)
	{
		return undef;
	}
	else
	{
		$condition =~ s/((?:$elem1|$elem3)\s*?)($op3)(\s*?(?:$elem1|$elem3))/$1$ops{$6}$7/g;
		$condition =~ s/($elem3)/Sifter::_escape_replace_tags($1)/ego;
		$condition =~ s/$elem4/"($1=~".Sifter::_escape_replace_tags($6).")"/eg;
		$condition =~ s/$elem1/\${\$replace}{'$1'}/g;

		return Sifter::_unescape_replace_tags($condition);
	}
}

##
# Escape replace tags
# 
# @return	string	String that includes escaped replace tags
# @param	string	$str  Source string
##
sub _escape_replace_tags#($str)
{
	my $str = shift;

	$str =~ s/($SIFTER_REPLACE_TAG_BGN)(\\*?$SIFTER_REPLACE_EXPRESSION$SIFTER_REPLACE_TAG_END)/$1\\$2/g;
	return $str;
}

##
# Unescape replace tags
# 
# @return	string	String that includes unescaped replace tags
# @param	string	$str  Source string
##
sub _unescape_replace_tags#($str)
{
	my $str = shift;

	$str =~ s/($SIFTER_REPLACE_TAG_BGN)\\(.+?$SIFTER_REPLACE_TAG_END)/$1$2/g;
	return $str;
}

##
# Extracts attribute from tag
# 
# @return	string	Value of attribute
# @param	string	$tag   Tag
# @param	string	$name  Name of attribute to extract
##
sub _get_attribute#($tag, $name)
{
	my $tag = shift;
	my $name = shift;

	if($tag =~ /\b$name=(\'|\"|\b)([^\1]*?)\1(?:\s|\/?>)/is)
	{
		return $2;
	}

	return undef;
}

##
# Sets attribute into tag
# 
# @return	string	Tag set attribute
# @param	string	$tag      Tag
# @param	string	$name     Name of attribute to set
# @param	string	$value    Value of attribute to set
# @param	bool	$verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
##
sub _set_attribute#($tag, $name, $value, $verbose=true)
{
	my $tag = shift;
	my $name = shift;
	my $value = shift;
	my $verbose = shift;

	$verbose = 1 if(!defined($verbose));

	my $ret;

	my $attr = $name.($verbose? '="'.$value.'"': '');
	if(!(($ret = $tag) =~ s/\b$name=(\'|\"|\b)[^\1]*?\1(\s|\/?>)/$attr$2/gis))
	{
		($ret = $tag) =~ s/<([^\/]+?)(\s*\/?)>/<$1 $attr$2>/s;
	}

	return $ret;
}

##
# Extracts id or name attribute from tag
# 
# @return	string	Value of id or name attribute
# @param	string	$tag  Tag
##
sub _get_element_id#($tag)
{

	my $tag = shift;

	my $ret;

	if(!defined($ret = Sifter::_get_attribute($tag, 'id')))
	{
		$ret = Sifter::_get_attribute($tag, 'name');
	}

	return $ret;
}

##
# Called by function _embed_values()
# 
# @return	string	Value embedded string
# @param	string	$str      Source string
# @param	array	$values   Array of values to embed
# @param	bool	$verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
##
sub _embed_values_callback#($str, &$values, $verbose)
{
	my $str = shift;
	my $values = shift;
	my $verbose = shift;

	my ($name, $value, $type, $flag, $select_name);

	my $element = $1 if($str =~ /^<(\/?.+?)\b/);
	if($element =~ /^input$/i)
	{
		$name = Sifter::_get_element_id($str);
		if(defined(${$values}{$name}))
		{
			$type = Sifter::_get_attribute($str, 'type');
			if($type =~ /^radio$/i || $type =~ /^checkbox$/i)
			{
				if(Sifter::_get_attribute($str, 'value') eq ${$values}{$name})
				{
					$str = Sifter::_set_attribute($str, 'checked', 'checked', $verbose);
				}
				else
				{
					$str =~ s/(<input.*)\s+checked(?:=(\"|\'|\b)checked\2)?(\s*\/?>)/$1$3/is;
				}
			}
			else
			{
				$str = Sifter::_set_attribute($str, 'value', ${$values}{$name});
			}
		}
	}
	elsif($element =~ /^textarea$/i)
	{
		$name = Sifter::_get_element_id($str);
		if(defined(${$values}{$name}))
		{
			$str =~ s/(<textarea\b.*?>).*?(<\/textarea>)/$1${$values}{$name}$2/is;
		}
	}
	elsif($element =~ /^select$/i)
	{
		if(!$SIFTER_SELECT_NAME)
		{
			($SIFTER_SELECT_NAME = Sifter::_get_element_id($str)) =~ s/\[\]$//;
		}
	}
	elsif($element =~ /^\/select$/i)
	{
		$SIFTER_SELECT_NAME = '';
	}
	elsif($element =~ /^option$/i)
	{
		if($SIFTER_SELECT_NAME && defined(${$values}{$SIFTER_SELECT_NAME}))
		{
			if(!defined($value = Sifter::_get_attribute($str, 'value')))
			{
				$value = $1 if($str =~ /<option\b.*?>(.*?)(?:<\/option>|[\r\n])/i);
			}

			$flag = 0;
			if(ref(${$values}{$SIFTER_SELECT_NAME}) eq 'ARRAY')
			{
				foreach(@{${$values}{$SIFTER_SELECT_NAME}})
				{
					if($_ eq $value)
					{
						$flag = 1;
						last;
					}
				}
			}
			elsif($value eq ${$values}{$SIFTER_SELECT_NAME})
			{
				$flag = 1;
			}

			if($flag)
			{
				$str = Sifter::_set_attribute($str, 'selected', 'selected', $verbose);
			}
			else
			{
				$str =~ s/(<option.*)\s+selected(?:=(\"|\'|\b)selected\2)?(\s*\/?>)/$1$3/is;
			}
		}
	}

	return $str;
}

##
# Embed value into element of form
# 
# @return	string		Value embedded string
# @param	resource	$str      Reference to source string
# @param	array		$values   Array of values to embed
# @param	bool		$verbose  If this parameter is true, "checked" and "selected" attributes are output verbosely
##
sub _embed_values#(&$str, &$values, $verbose=true)
{
	my $str = shift;
	my $values = shift;
	my $verbose = shift;

	$verbose = 1 if(!defined($verbose));

	${$str} =~ s/($SIFTER_EMBED_EXPRESSION)/Sifter::_embed_values_callback($1,$values,$verbose)/egios;
}

##
# Convert HTML entities
# 
# @param	mixed	$value  String or array to convert
##
sub _convert_html_entities#(&$value)
{
	my $value = shift;

	my $key;

	if(ref($value) eq 'REF')
	{
		Sifter::_convert_html_entities(${$value});
	}
	elsif(ref($value) eq 'ARRAY')
	{
		foreach $key (0..$#{$value})
		{
			Sifter::_convert_html_entities(\${$value}[$key]);
		}
	}
	elsif(ref($value) eq 'HASH')
	{
		foreach $key (keys(%{$value}))
		{
			Sifter::_convert_html_entities(\${$value}{$key});
		}
	}
	else
	{
		${$value} =~ s/\&/\&amp;/g;
		${$value} =~ s/\"/\&quot;/g;
		${$value} =~ s/\</\&lt;/g;
		${$value} =~ s/\>/\&gt;/g;
	}
}

##
# Called by function format()
# 
# @return	string	Formatted value
# @param	string	$value    Value
# @param	string	$comma    If this parameter is set, numeric value will be converted to comma formatted value
# @param	string	$options  Options
##
sub _format_callback#($value, $comma='', $options='')
{
	my $value = shift;
	my $comma = shift;
	my $options = shift;

	if($comma)
	{
		$value =~ s/^(($SIFTER_DECIMAL_EXPRESSION)?).*/$1/;
		my @temp = split('\.', sprintf('%.*lf', int(substr($comma, 1) || 0), $value || 0));
		1 while($temp[0] =~ s/(\d)(\d\d\d)(?!\d)/$1,$2/g);
		$value = join('.', @temp);
	}

	if($options)
	{
		if(index($options, 'b') >= 0)
		{
			# Convert linebreaks to "<br />"
			$value =~ s/(\r?\n)/<br \/>$1/g;
		}
		if(index($options, 'q') >= 0)
		{
			# Escape quotes, backslashes and linebreaks
			$value =~ s/([\'\"\\]|&quot;)/\\$1/g;
			$value =~ s/\r/\\r/g;
			$value =~ s/\n/\\n/g;
		}
	}

	return $value;
}

##
# Called by function format()
# 
# @return	string	Formatted value
# @param	array	$replace    Array of replacement
# @param	string	$key        Value
# @param	string	$operation  Arithmetic operation
# @param	string	$comma      If this parameter is set, numeric value will be converted to comma formatted value
# @param	string	$options    Options
##
sub _format
{
	my $replace = shift;
	my $key = shift;
	my $operation = shift;
	my $comma = shift;
	my $options = shift;

	return '' if(ref($replace) ne 'HASH');

	my $value = (defined(${$replace}{$key})? ${$replace}{$key}: '');

	if($operation)
	{
		$value =~ s/^(($SIFTER_DECIMAL_EXPRESSION)?).*/$1/;
		$value = 0 if($value eq '');
		$value = eval($value.$operation);
	}

	return Sifter::_format_callback($value, $comma, $options);
}

##
# Format string
# 
# @return	string	Formatted string
# @param	string	$format   Format string
# @param	array	$replace  Array of replacement
##
sub format#($format, &$replace)
{
	my $this = shift;
	my $format = (ref($this)? shift: $this);
	my $replace = shift;

	$format =~ s/$SIFTER_REPLACE_PATTERN/Sifter::_format($replace, $1, $2, $3, $4)/eg;
	return $format;
}

1;
__END__

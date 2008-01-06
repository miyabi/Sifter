<?php

require('../Sifter.php');
$template = new Sifter;
$template->set_var('foo', 'bar');
$template->set_var('condition', 'true');
$template->set_var('array', array(array('loop'=>1), array('loop'=>2), array('loop'=>3)));
$template->display('sample.tmpl');

?>

<?php

function subtract($number1, $number2){
	if($number1 > $number2){
		return ($number1 - $number2);
	} else {
		return ($number2 - $number1);
	}
}

function rgb2irc($red, $green, $blue){
	$total = 99999999;
	$palette = array('255255255','000000000','000000127','000147000','255000000','127000000','156000156',
			'252127000','255255000','000252000','000147147','000255255','000000252','255000255',
			'127127127','210210210');

	for($i=0;$i<count($palette);$i++){
		$red2 = substr($palette[$i], 0, 3);
		$green2 = substr($palette[$i], 3, 3);
		$blue2 = substr($palette[$i], 6, 8);

		$diff1 = subtract($red, $red2);
		$diff2 = subtract($green, $green2);
		$diff3 = subtract($blue, $blue2);
		$new_total = $diff1 + $diff2 + $diff3;

		if($new_total < $total){
			$rgbcol = $palette[$i];
			$total = $new_total;
			$color = $i;
		}
		unset($new_total);
	}
	
	return $color;
}

?>
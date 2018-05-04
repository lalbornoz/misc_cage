<?php
require_once("rgb2irc.php");

function image2ascii($image, $show_color='0', $show_ircbg='0', $raw=0, $double=1, $same=false){
	if($raw == 0){
		$image = str_replace(" ", "%20", $image);
		if(eregi(".gif$", $image)){
			$image = imagecreatefromgif($image);
		} elseif(eregi(".(jpg|jpeg)$", $image)){
			$image = imagecreatefromjpeg($image);
		} elseif(eregi(".png$", $image)){
			$image = imagecreatefrompng($image);
		} else {
			$error = true;
		}
	}

	$width = imagesx($image);
	$height = imagesy($image);

	if(!$image){
		$error = true;
	}

	if(!$error){
	$x_wid=1;
	for($y=0;$y<$height;$y++){
		for($x=0;$x<$width;$x++){
			$rgb = ImageColorAt($image, $x, $y);
			$colors = imagecolorsforindex($image, $rgb);
			$hex = '#' . dechex($colors[red]) . dechex($colors[green]) . dechex($colors[blue]);
			$average = round(($colors[red] + $colors[green] + $colors[blue]) / 3);

			if ($average < 17) {
				$letter = '@';
			} else if($average < 34){
				$letter = '#';
			} else if($average < 51){
				$letter = '$';
			} else if($average < 68){
				$letter = '%';
			} else if($average < 85){
				$letter = '&';
			} else if($average < 102){
				$letter = '/';
			} else if($average < 119){
				$letter = '|';
			} else if($average < 136){
				$letter = '?';
			} else if($average < 153){
				$letter = '~';
			} else if($average < 170){
				$letter = '*';
			} else if($average < 187){
				$letter = '+';
			} else if($average < 204){
				$letter = ':';
			} else if($average < 221){
				$letter = ',';
			} else if($average < 238){
				$letter = '.';
			} else if($average < 256){
				if(!$_REQUEST['nodot']){
					$letter = ' ';
				} else {
					$letter = '\'';
				}
			}

			if($same || $show_ircbg){
				$letter = "@";
			}

			$new_col = rgb2irc($colors[red], $colors[green], $colors[blue]);

			if($double){
				$add = $letter.$letter;
			} else {
				$add = $letter;
			}
	
			if($show_ircbg) {
				$out .= "" . $new_col . "," . $new_col . $add . "";
			} elseif($show_color){
				$out .= "" . $new_col . $add . "";
			} else {
				$out .= $add;
			}

			if($x_wid == $width){
				$out .= "$string\r\n";
				$x_wid = 1;
			} else {
				$x_wid++;
			}	
		}
	}
	imagedestroy($image);
	return $out;
	}
}

?>


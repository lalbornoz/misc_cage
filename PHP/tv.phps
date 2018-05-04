<?php
/**
 * tv.php -- Retrieve TV programmes in IRC format
 */

/* CXmlReader subclass, this will do the actual work of this class */
class CXmlReader 
{
      private $array;
    private $parser;
    private $pointer;

    /**
     * Invoke the parser, ($obj = new XmlReader($xml)) 
     */
        public function __construct
    (
        $xml
    ) 
    {
        $this->pointer = &$this->array;
          $this->parser = xml_parser_create();
          xml_set_object($this->parser, $this);
          xml_parser_set_option($this->parser, XML_OPTION_CASE_FOLDING, false);
          xml_parser_set_option($this->
parser, XML_OPTION_TARGET_ENCODING, "UTF-8");
        xml_set_element_handler($this->parser, "tag_open", "tag_close");
          xml_set_character_data_handler($this->parser, "cdata");
          xml_parse($this->parser, ltrim($xml));
    }

        private function tag_open
    (
        $parser, 
        $tag, 
        $attributes
    ) 
    {
                $idx = $this->convert_to_array($tag, 'attrib');
          $idx = $this->convert_to_array($tag, 'cdata');      
            
        if (isset($idx)) { 
                $this->pointer[$tag][$idx] = array('@idx' => $idx,'@parent' => 
&$this->pointer);
                $this->pointer = &$this->pointer[$tag][$idx];
          } else {
                $this->pointer[$tag] = array('@parent' => &$this->pointer);
                $this->pointer = &$this->pointer[$tag];
          }
  
        if (! empty($attributes)) { 
                $this->pointer['attrib'] = $attributes; 
                }
    }

        private function cdata
    (
        $parser, 
        $cdata
    ) 
    { 
        $this->pointer['cdata'] .= trim($cdata); 
    }

        private function tag_close
    (
        $parser, 
        $tag
    ) 
    {
          $current = &$this->pointer;
                  
        if (isset($this->pointer['@idx'])) {
                    unset($current['@idx']);
                }
  
        $this->pointer = & $this->pointer['@parent'];
        unset($current['@parent']);
  
        if (isset($current['cdata']) && count($current) == 1) { 
                $current = $current['cdata'];
        } else if (empty($current['cdata'])) {
                unset($current['cdata']);
                }
    }

    /**
      * Converts a single element item into array(element[0])
 if a second element of the same name is encountered.
      */
    private function convert_to_array
    (
        $tag, 
        $item
    ) 
    {
                if (isset($this->pointer[$tag][$item])) {
                    $content = $this->pointer[$tag];
                        $this->pointer[$tag] = array((0) => $content);
                       $idx = 1;
        } else if (isset($this->pointer[$tag])) {
                $idx = count($this->pointer[$tag]);
                      
                if (! isset($this->pointer[$tag][0])) {
                foreach ($this->pointer[$tag] as $key => $value) {
                              unset($this->pointer[$tag][$key]);
                              $this->pointer[$tag][0][$key] = $value;
                }
                }
            
                } else {
                $idx = null;
                }
  
        return $idx;
    }

    /**
      * Array getter
     */
    public function getarray
    ()
    {
        return $this->array;
    }
            
};

/* TV Programme */
class CTVProgramme
{
    public $startTime;
    public $stationTitle;
    public $programmeTitle;
    public $description;
    public $detailLink;
    public $genre;
    public $country;
    public $year;

    public function __construct
    (
        $_station,
        $_time,
        $_title,
        $_description,
        $_link,
        $_genre,
        $_country,
        $_year
    )
    {
        $this->startTime = $_time;
        $this->stationTitle = $_station;
        $this->programmeTitle = $_title;
        $this->description = $_description;
        $this->detailLink = $_link;
        $this->genre = $_genre;
        $this->country = $_country;
        $this->year = $_year;
    }

};
        
/
* Perform an XML request on one of the provided sources, and return the data as array *
/ 
class CXmlRequest 
{
    
    /* Collection of base urls */
    public $base_urls = array(
                   'tvmovie' => 'http://www.tvmovie.de/rss/',
                 );

    /* Collection of feeds in relation to the base urls */
    public $feeds = array(
                'tvmovie' => array(
                            'now' => 'tvjetzt.xml',
                            'primetime' => 'tv2015.xml',
                            'latetime' => 'tv2200.xml',
                            'tipps' => 'tvtipps-spielfilm.xml',
                            ),
                 );

    /* Determines whether our data is possibly outdated */
    public $outdated = false;
    public $makedate;
    private $programmes;

    public function getprogrammes
    ()
    {
        return $this->programmes;
    }    

    public function __construct
    (
        $searchParams = 0,
        $baseUrlNo = 0,
        $feedNo = 0
    )
    {
        /* Retrieve the base url */
        $baseUrlNumericArray = array_values($this->base_urls);
        $baseUrlKeyAssoc = array_keys($this->base_urls);
        
        /* Retrieve the feed file */
        $feedsNumericArray = array_values($this->feeds[$baseUrlKeyAssoc
[$baseUrlNo]]);        

        /* Build the request url */
        $fullRequestUrl = $baseUrlNumericArray[$baseUrlNo].$feedsNumericArray
[$feedNo];
        
        /* Free the crappy temporary arrays */
        unset($baseUrlNumericArray);
        unset($baseUrlKeyAssoc);
        unset($feedsNumericArray);

        $XmlData = file_get_contents($fullRequestUrl);
        //$XmlData = str_replace(' / ', '§', $XmlData);
        //$XmlData = str_replace('&', '$', $XmlData);
        $XmlReader = new CXmlReader($XmlData);
        $this->parsexml($XmlReader->getarray());
        unset($XmlReader);    
        
    }        

    private function convertxmltoirc
    (
        $fullStr = ''
    )
    {
        return html_entity_decode($fullStr, ENT_QUOTES);
    }

    /* Parse our raw xml data into an array of `CTVProgramme' objects */
    private function parsexml
    (
        $array = array()
    )
    {
        /
* Check if what we got is actually RSS data, this is our last sanity check, if anything goes wrong beyond this point
         * it is not our fault, as we operate independently from the data structure we received by employing mnemonics 
         */
        if (! isset($array['rss'])) 
            die
("Whatever has been received as RSS data, could not be parsed. Please make sure you used the correct configuration.");
 
        
        /* Split off the relevant data from the RSS hive */
        $data = $array['rss']['channel']['item'];
        $published = $array['rss']['channel']['pubDate'];

        /* Convert the time string (Tue, 07 Sep 2010 19:12:02 +0200)
 back to unix format */
        $localeBackup = setlocale(LC_TIME, NULL); /
* since we are about to change our locale, we back the original one up */
        setlocale(LC_TIME, 'C'); /* use the `C' locale */
        $publishedStamp = strtotime($published); /* convert, and... */
        setlocale(LC_TIME, $localeBackup); /* revert to our original locale */
        
        /* Now, find out if this data is out-of-date (=
older than 3 hours), and set the flag accordingly so we may raise a warning later on *
/
        $this->outdated = (time() - $publishedStamp) > 10800;
        $this->makedate = $published;        

        /* Now begins the best part, parsing! */
        foreach ($data as $item) {
            /* Convert all HTML entities of all relevant members */
            $item['title'] = $this->convertxmltoirc($item['title']);
            $item['link'] = $this->convertxmltoirc($item['link']);
            $item['description'] = $this->convertxmltoirc($item
['description']);
            
            $tempDesc = strstr($item['description'], '/');
            $item['description'] = substr($item['description'], 0, strpos($item
['description'], '/'));

            list($t['time'], $t['station'], $t['title']) = sscanf($item
['title'], "%s %[^-]- %[^\n]");
            list($t['genre'], $t['country'], $t['year'], $t['description']) =
 sscanf($item['description'], "%[^-]- %s %d%[^\n]");
            
            if (! strlen($t['genre'])) 
                $t['genre'] = 'none ';
            
            if (! strlen($t['year']))
                $t['year'] = 'none';

            $this->programmes []= new CTVProgramme($t['station'], $t
['time'], $t['title'], substr($tempDesc, 1), $item['link'], $t['genre'], $t
['country'], $t['year']);
        }
    }
};

class TV 
{
    private $programmes;
    private $XmlRequest;
    private $stationMax = 0;
    private $genreMax = 0;
    private $titleMax = 70;

    private function utf8sprintf 
    (
        $format
    ) 
    {
          $args = func_get_args();

          for ($i = 1; $i < count($args); $i++) {
                $args[$i] = iconv('UTF-8', 'ISO-8859-2', $args [$i]);
          }
 
          return iconv('ISO-8859-2', 'UTF-8', call_user_func_array
('sprintf', $args));
    }

    public function __construct
    (
        $searchParams = 0,
        $baseUrlNo = 0,
        $feedNo = 0,
        $stationFilter = '*',
        $titleFilter ='*'
    )
    {
        $this->XmlRequest = $XmlRequest = new CXmlRequest
($searchParams, $baseUrlNo, $feedNo);
        $this->programmes = $XmlRequest->getprogrammes();

        switch ($searchParams) {
            case 0: $this->filter($stationFilter, $titleFilter); break;
            case 1: $this->favouritefilter(); break;
            default: break;
        }
        if (! $searchParams) {        
            $this->filter($stationFilter, $titleFilter);
        }
        $this->sortprogrammes();
    }

    private function colourstation
    (
        $station = ''
    )
    {
    /*    $stationToColour = 
            array(
                'sixx ' => "\00303sixx \00301",
                'PRO 7 ' => "\00304PRO.7 \00301",
                'ARD ' => "\00311ARD \00301",
                );

        foreach ($stationToColour as $st => $newst) {
            if ($st == $station)
                return $newst;
        }

        return "\00301".$station."\00301";*/
        return $station;
    }

    public function show
    (
        $fulldesc = false
    )
    {
        echo "RSS feed was generated at: ".$this->XmlRequest->makedate."\n";
        

        /* Generate a format string */
        /* Find out whether the word 
` Station ' is longer than the longest station */
        if (strlen("Station ") > $this->stationMax)
            $this->stationMax = strlen("Station" );

        $fmtstring = sprintf("%%%ds %%%ds", $this->stationMax+1, $this->
genreMax+1);
        $tfmtstring = sprintf("%%-%ds", $this->titleMax+3);

        /* Print table head */
        $tablefmt = sprintf("%%s %s %%s %s\n", $fmtstring, $tfmtstring);
        $tablehead = "\0030,14".sprintf
($tablefmt, "Time ", "Station ", "Genre ", "Year ", "Show title");
        echo $tablehead;        

        $i = 0;
        foreach ($this->programmes as $programme) {
            /* Generate a colour code */
            $colourCode = (! ($i++ % 2)) ? "\0031,15" : "\0031,14";
            $output  = $colourCode;        
            $output .= $programme->startTime." ";
            $output .= $this->utf8sprintf($fmtstring,$this->colourstation
($programme->stationTitle), $programme->genre)." ";
            $output .= $programme->year."  ";
            //$output .= $this->utf8sprintf($tfmtstring,$programme->
programmeTitle);

            /* Find out how much space (if any) is left for descriptions */
            $spaceLeft = ($this->titleMax) - strlen($programme->programmeTitle)
 - 6;

            if ($spaceLeft > 10 && strlen($programme->description)) {
                $infoString = $programme->programmeTitle." - ";
                $infoString .= ltrim(substr(str_replace("<br>
", " ", $programme->description), 0, $spaceLeft))."...";
            } else
                $infoString = $programme->programmeTitle;

            $output .= $this->utf8sprintf($tfmtstring, $infoString);
                
            /* Encode and print output */
            echo utf8_decode($output)."\n";
        }
    }

    public function sortprogrammes
    ()
    {
        
    }
    
    public function filter
    (
        $station = '*',
        $title = '*'
    )
    {    
        foreach ($this->programmes as $programme) {
            if (fnmatch($station, str_replace(' ', '', $programme->
stationTitle), FNM_CASEFOLD) &&
                fnmatch($title, $programme->programmeTitle, FNM_CASEFOLD)) {
                $programmes []= $programme;

                if (strlen($programme->stationTitle) > $this->stationMax) 
                    $this->stationMax = strlen($programme->stationTitle);
          
            
                if (strlen($programme->genre) > $this->genreMax)
                    $this->genreMax = strlen($programme->genre);
            
                if (strlen($programme->programmeTitle) > $this->titleMax)
                    $this->titleMax = strlen($programme->programmeTitle);
            }
        }

        $this->programmes = $programmes;
    }

    public function filterfavourites
    ()
    {
    }
};

/** 
 * Process our $_GET requests
 */

/**
 * Default values 
 */

$baseUrlNo = 0;
$feedNo = 0;

if (isset($_GET['request'])) {
    $request = $_GET['request']; 
    $args = explode(' ', $request);
    
    for ($i = 0; $i < count($args); $i++) {
        switch ($args[$i]) {
            case '--now':$baseUrlNo = 0; $feedNo = 0; break;
            case '--primetime':$baseUrlNo = 0; $feedNo = 1; break;
            case '--latetime':$baseUrlNo = 0; $feedNo = 2; break;
            case '--tipps':$baseUrlNo = 0; $feedNo = 3; break; 
        }
    } 
}

$TV = new TV(0, $baseUrlNo, $feedNo, '*', '*');
$TV->show();
?>

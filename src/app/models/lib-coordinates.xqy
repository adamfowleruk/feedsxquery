(:
Copyright 2012 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)
(: Author: Adam Fowler <adam.fowler@marklogic.com> :)
xquery version "1.0-ml";

module namespace m = "http://marklogic.com/lib-coordinates";

declare namespace epsg4326 = "http://spatialreference.org/ref/epsg/4326/";
declare namespace osgb36 = "http://spatialreference.org/ref/epsg/4277/";


declare function m:ngr-to-epsg4326($ngr as xs:string) as element(epsg4326:epsg4326) {
  m:osgb36-to-epsg4326(m:ngr-to-osgb36($ngr))
};

declare function m:ngr-to-osgb36($ngr as xs:string) as element(osgb36:osgb36) {
  
  let $ref := fn:upper-case($ngr) 
  let $fullref := fn:replace($ref," ","")
    
  let $first := fn:substring($fullref,1,1)
  let $log := xdmp:log(fn:concat("First Letter: ",$first))
  let $quadrant :=
      if ("S" = $first) then
        <q><e>0</e><n>0</n></q>
      else if ("T" = $first) then
        <q><e>500000</e><n>0</n></q>
      else if ("N" = $first) then
        <q><e>500000</e><n>0</n></q>
      else if ("O" = $first) then
        <q><e>500000</e><n>500000</n></q>
      else if ("H" = $first) then
        <q><e>1000000</e><n>0</n></q>
      else 
        <q><e>0</e><n>0</n></q>
      
  let $second := fn:substring($fullref,2,1)
  let $log := xdmp:log(fn:concat("Second Letter: ",$second))
  let $letterval := fn:string-to-codepoints($second)[1] - 65
  let $letterval :=
    if ($letterval gt 8) then
      $letterval - 1
    else
      $letterval
      
  let $log := xdmp:log(fn:concat("second Letter value: ",$letterval))
		(: c = ngr.charCodeAt(1) - 65; :)
		
	let $log := xdmp:log(fn:concat("letterval mod 5: ",(math:fmod($letterval,5.0)),", letterval div 5.0: ",($letterval div 5.0)))

  let $finalval := map:map()
  let $p := map:put($finalval,"value",$letterval)
  let $subsector :=
    if ($letterval gt 8) then
      (<s><e>{(math:fmod($letterval,5.0)) * 100000}</e><n>{(4 - fn:floor($letterval div 5.0) ) * 100000}</n></s>,map:put($finalval,"value",$letterval - 1))
    else
      <s><e>0</e><n>0</n></s>
      
  let $numbers := fn:substring($fullref,3,fn:string-length($fullref) - 1) 
  let $log := xdmp:log(fn:concat("Fullref: ",$fullref,", Numbers: ",$numbers))
  let $partlength := fn:string-length($numbers) div 2
  let $log := xdmp:log(fn:concat("Grid Ref number part length: ",$partlength))
  let $easting := 
    let $eo := fn:substring($fullref,3,$partlength)
    return ($eo cast as xs:integer) * math:pow(10,(5 - $partlength)) (: VERIFY :)
  let $northing := 
    let $no := fn:substring($fullref,3+$partlength,$partlength)
    return ($no cast as xs:integer) * math:pow(10,(5 - $partlength)) (: VERIFY :)
    
  let $log := xdmp:log(fn:concat("Partial Easting: ",$easting,", Northing: ",$northing))
  let $log := xdmp:log(fn:concat("Quadrant Easting: ",xs:integer($quadrant/e/text()),", Northing: ",xs:integer($quadrant/n/text())))
  let $log := xdmp:log(fn:concat("Subsector Easting: ",xs:integer($subsector/e/text()),", Northing: ",xs:integer($subsector/n/text())))
  
  (: now add them all together :)
  let $n := $northing + (xs:integer($quadrant/n/text())) + (xs:integer($subsector/n/text()))
  let $e := $easting + (xs:integer($quadrant/e/text())) + (xs:integer($subsector/e/text()))
  let $log := xdmp:log(fn:concat("OSGB36: Easting: ",$e,", Northing: ",$n))
  
  return (:
    <osgb36:osgb36 lat="{$n}" lon="{$e}" /> :)
    element osgb36:osgb36 {
      attribute lat {
        $n
      }, attribute lon {
        $e
      }
    }
};

declare function m:osgb36-to-string($osgb36 as element(osgb36:osgb36)) as xs:string {
  let $lat := xs:double($osgb36/@lat) 
  let $long := xs:double($osgb36/@lon)
  return fn:concat("OSGB36 Longitude: ",$long,", Latitude: ",$lat)
};

declare function m:osgb36-to-epsg4326($osgb36 as element(osgb36:osgb36)) as element(epsg4326:epsg4326) {
  let $log := xdmp:log($osgb36)
  let $north := xs:double($osgb36/@lat) 
  let $east := xs:double($osgb36/@lon)
  let $log := xdmp:log(fn:concat("OSGB36 Longitude: ",$east,", Latitude: ",$north))
  
    (: WARNING - This method has east and north mixed up. It has been tested and DOES produce the correct results. :)
    
		let $K0 := xs:double(0.9996012717)  (: grid scale factor on central meridean :)
		let $OriginLat :=  xs:double(49.0)
		let $OriginLong :=  xs:double(-2.0)    
		let $OriginX := 400000 (: 400 kM :)
		let $OriginY := -100000 (: 100 kM :)
		let $a :=  xs:double(6377563.396) (: Airy Spheroid :)
		let $b :=  xs:double(6356256.910)
(:
		var 	e2;
		var 	ex;
		var 	n1;
		var 	n2;
		var 	n3;
		var 	OriginNorthings;
:)

		(: compute interim values :)
		let $a := $a * $K0
		let $b := $b * $K0

		let $n1 := ($a - $b) div ($a + $b)
		let $n2 := $n1 * $n1
		let $n3 := $n2 * $n1 

		let $lat := $OriginLat * math:pi() div 180.0 (: to radians        :)                                             


		let $e2 := ($a*$a - $b*$b) div ($a*$a)  (: first eccentricity :)
		let $ex := ($a*$a - $b*$b) div ($b*$b)  (: second eccentricity :)


		let $OriginNorthings := $b*$lat + $b*($n1*(1.0 + 5.0*$n1*(1.0+$n1) div 4.0)*$lat         
		  - 3.0*$n1*(1.0+$n1*(1.0+7.0*$n1 div 8.0))*math:sin($lat)*math:cos($lat)
		  + (15.0*$n1*($n1+$n2) div 8.0)*math:sin(2.0*$lat)*math:cos(2.0*$lat)
		  - (35.0*$n3 div 24.0)*math:sin(3.0*$lat)*math:cos(3.0*$lat) )

		let  $OriginLat := xs:double(49.0)
		let  $OriginLong := xs:double(-2.0)   
		let  $OriginX := xs:double(400000) (: 400 kM :)
		let  $OriginY := xs:double(-100000) (: 100 kM :)

(:
		var lat;    // what we calculate
		var lon;
:)
		let  $northing := $north - $OriginY
		let  $easting := $east - $OriginX
(:
		var nu, phid, phid2, t2, t, q2, c, s, nphid, dnphid; // temps
		var nu2, nudivrho, invnurho, rho, eta2;
:)

		(: Evaluate M term: latitude of the northing on the centre meridian :) 

		let $northing := $northing + $OriginNorthings  

		let $phid := $northing div ($b*(1.0 + $n1 + 5.0*($n2+$n3) div 4.0)) - 1.0
		let $phid2 := $phid + 1.0

(:
		while (fn:abs($phid2 - $phid) gt 1E-6)
		{
			let $phid := $phid2
			let $nphid := $b*$phid + $b*($n1*(1.0 + 5.0*$n1*(1.0+$n1) div 4.0)*$phid
			  - 3.0*$n1*(1.0+$n1*(1.0+7.0*$n1 div 8.0))*math:sin($phid)*math:cos($phid)
			  + (15.0*$n1*($n1+$n2) div 8.0)*math:sin(2.0*$phid)*math:cos(2.0*$phid)
			  - (35.0*$n3 div 24.0)*math:sin(3.0*$phid)*math:cos(3.0*$phid) )

			let $dnphid := $b*((1.0+$n1+5.0*($n2+$n3) div 4.0)-3.0*($n1+$n2+7.0*$n3 div 8.0)*math:cos(2.0*$phid)
			  +(15.0*($n2+$n3) div 4.0)*math:cos(4*$phid)-(35.0*n$3 div 8.0)*math:cos(6.0*$phid))

			let $phid2 := $phid - ($nphid - $northing) div $dnphid
		}
		:)
		let $phidresult := m:phid-reduce($phid,$phid2,$northing,$b,$n1,$n2,$n3)
		let $phid := xs:double($phidresult/phid/text())
		let $phid2 := xs:double($phidresult/phid2/text())

		let $c  := math:cos($phid)
		let $s  := math:sin($phid)
		let $t  := math:tan($phid)
		let $t2 := $t*$t
		let $q2 := $easting*$easting


		let $nu2 := ($a*$a) div (1.0 - $e2*$s*$s)
		let $nu := math:sqrt($nu2)

		let $nudivrho := $a*$a*$c*$c div ($b*$b) - $c*$c + 1.0

		let $eta2 := $nudivrho - 1

		let $rho := $nu div $nudivrho

		let $invnurho := ((1.0-$e2*$s*$s)*(1.0-$e2*$s*$s)) div ($a*$a*(1.0-$e2))

		let $lat := $phid - $t*$q2*$invnurho div 2.0 + ($q2*$q2*($t div (24*$rho*$nu2*$nu)*(5 + (3*$t2) + $eta2 -(9*$t2*$eta2))))

		let $lon := ($easting div ($c*$nu))
		  - ($easting*$q2*(($nudivrho+2.0*$t2) div (6.0*$nu2)) div ($c*$nu))
		  + ($q2*$q2*$easting*(5 + (28*$t2) + (24*$t2*$t2)) div (120*$nu2*$nu2*$nu*$c))

		return (:<epsg4326:epsg4326 lon="{($lon * 180.0 div math:pi()) + $OriginLong}" lat="{$lat * 180.0 div math:pi()}" /> :)
		  element epsg4326:epsg4326 {
		    attribute lon {
		      ($lon * 180.0 div math:pi()) + $OriginLong
		    }, attribute lat {
		      $lat * 180.0 div math:pi()
		    }
		  } 
};



declare function m:epsg4326-to-string($epsg4326 as element(epsg4326:epsg4326)) as xs:string {
  let $lat := xs:double($epsg4326/@lat) 
  let $long := xs:double($epsg4326/@lon)
  return fn:concat("EPSG4326(WGS84) Longitude: ",$long,", Latitude: ",$lat)
};

(: Horrible recursive way to avoid a while loop :)
declare function m:phid-reduce($phid as xs:double,$phid2 as xs:double,$northing as xs:double,$b as xs:double,$n1 as xs:double,$n2 as xs:double,$n3 as xs:double) {
  if (fn:abs($phid2 - $phid) gt 1E-6) then
    (: DO WORK AND CALL OURSELVES :)
			let $phid := $phid2
			let $nphid := $b*$phid + $b*($n1*(1.0 + 5.0*$n1*(1.0+$n1) div 4.0)*$phid
			  - 3.0*$n1*(1.0+$n1*(1.0+7.0*$n1 div 8.0))*math:sin($phid)*math:cos($phid)
			  + (15.0*$n1*($n1+$n2) div 8.0)*math:sin(2.0*$phid)*math:cos(2.0*$phid)
			  - (35.0*$n3 div 24.0)*math:sin(3.0*$phid)*math:cos(3.0*$phid) )

			let $dnphid := $b*((1.0+$n1+5.0*($n2+$n3) div 4.0)-3.0*($n1+$n2+7.0*$n3 div 8.0)*math:cos(2.0*$phid)
			  +(15.0*($n2+$n3) div 4.0)*math:cos(4*$phid)-(35.0*$n3 div 8.0)*math:cos(6.0*$phid))

			let $phid2 := $phid - ($nphid - $northing) div $dnphid
			
			return m:phid-reduce($phid,$phid2,$northing,$b,$n1,$n2,$n3)
  else
    (: RETURN INPUT AS RESULT :)
    <result><phid>{$phid}</phid><phid2>{$phid2}</phid2></result>
};

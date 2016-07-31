
<?php

class LocationSeeder extends Seeder {
    public function run(){
    	
		$totalSeeds = 100;

		for($i=0; $i<$totalSeeds; $i++){
		$lat = rand(100, 999);
		$long = rand(100, 999);
		$userId = Hash::make($lat . "" . $long);
        
		$location = new Locations;
		$location->userId = $userId;
		$location->latitude = $lat;
		$location->longitude = $long;
		$location->save();
        }
        
    }
}

?>
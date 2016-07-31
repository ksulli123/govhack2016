<?php

class LocationController extends \BaseController {

	/**
	 * Display a listing of the resource.
	 *
	 * @return Response
	 */
	public static function index()
	{
		  $area = Request::query('area');
		  
          $latitude = Request::query('longitude');
          $longitude = Request::query('latitude');
          $date = new DateTime;
          $date->modify('-30 minutes');
          $formatted_date = $date->format('Y-m-d H:i:s');
          
          $data = DB::table('Locations')
          ->where('longitude', '>=', $longitude-$area/2)
          ->where('longitude', '<=', $longitude+$area/2)
          ->where('latitude', '>=', $latitude-$area/2)
          ->where('latitude', '<=', $latitude+$area/2)
          //->where('created_at','<=', $formatted_date)
          ->distinct('userId')
          ->get(); 
          
          return Response::json($data);
	}


	/**
	 * Show the form for creating a new resource.
	 *
	 * @return Response
	 */
	public function create()
	{
		//
	}


	/**
	 * Store a newly created resource in storage.
	 *
	 * @return Response
	 */
	public function store()
	{
		//
	}


	/**
	 * Display the specified resource.
	 *
	 * @param  int  $id
	 * @return Response
	 */
	public function show($id)
	{
		//
	}


	/**
	 * Show the form for editing the specified resource.
	 *
	 * @param  int  $id
	 * @return Response
	 */
	public function edit($id)
	{
		//
	}


	/**
	 * Update the specified resource in storage.
	 *
	 * @param  int  $id
	 * @return Response
	 */
	public function update($id)
	{
		//
	}


	/**
	 * Remove the specified resource from storage.
	 *
	 * @param  int  $id
	 * @return Response
	 */
	public function destroy($id)
	{
		//
	}


}

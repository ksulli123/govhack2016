<?php

use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class CreateSearchTables extends Migration {

	/**
	 * Run the migrations.
	 *
	 * @return void
	 */
	public function up()
	{
		Schema::create('UserData', function($table){
                             $table->string('HexString');
                             $table->timestamps();
                    });
		
			Schema::create('Locations', function($table){
				$table->increments('id');
				$table->string('userId');
				$table->double('longitude');
				$table->double('latitude');
				$table->timestamps();
			});
	}

	/**
	 * Reverse the migrations.
	 *
	 * @return void
	 */
	public function down()
	{
		Schema::drop('UserData');
		Schema::drop('Locations');
	}

}

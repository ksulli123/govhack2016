@extends('product.layout')

@section('title')
    Create
@stop

@section('sidebar')
    <p>This is the sidebar</p>
@stop

@section('body')

    {{ Form::open(array('url'=> secure_url('user'))) }}
        {{ Form::label('username', 'User Name: ') }}
        {{ Form::text('username') }}
        {{ $errors->first('username') }}
        <p></p>
        {{ Form::label('password', 'Password: ') }}
        {{ Form::text('password') }}
        {{ $errors->first('password') }}
        <p></p>
        {{ Form::submit('Create') }}
    {{ Form::close() }}
    <br>
@stop

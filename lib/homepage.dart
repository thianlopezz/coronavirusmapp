import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatefulWidget {
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _filter = new TextEditingController();
  Icon searchIcon = new Icon(Icons.search);
  Widget appBarTitle = new Text('COVID 19');

  final dio = new Dio(); // for http requests

  String _searchText = "";
  String updatedAt = "";
  List inffectedCountries = new List();
  List inffectedCountriesFiltered = new List();

  HomePageState() {
    _filter.addListener(() {
      if (_filter.text.isEmpty) {
        setState(() {
          _searchText = "";
          inffectedCountriesFiltered = inffectedCountries;
        });
      } else {
        setState(() {
          _searchText = _filter.text;
          inffectedCountriesFiltered = inffectedCountries.where((country) {
            return country['country_name']
                        .toUpperCase()
                        .indexOf(_searchText.toUpperCase()) !=
                    -1 ||
                country['altSpellings'].indexWhere(
                      (alt) =>
                          alt
                              .toUpperCase()
                              .indexOf(_searchText.toUpperCase()) !=
                          -1,
                    ) !=
                    -1;
          }).toList();
        });
      }
    });
  }

  @override
  void initState() {
    this.getData();
    super.initState();
  }

  void getData() async {
    final allCountriesResponse =
        await dio.get('https://restcountries.eu/rest/v2/all');

    List _allCountries = new List();
    for (int i = 0; i < allCountriesResponse.data.length; i++) {
      _allCountries.add(allCountriesResponse.data[i]);
    }

    final inffectedCountriesResponse = await dio.get(
        'https://coronavirus-monitor.p.rapidapi.com/coronavirus/cases_by_country.php',
        options: Options(headers: {
          'x-rapidapi-host': 'coronavirus-monitor.p.rapidapi.com',
          'x-rapidapi-key':
              'b977b4931cmshc1242005fd952fep1abf72jsn9013efcf73e7',
        }));

    Map responseMap = json.decode(inffectedCountriesResponse.data);

    List _inffectedCountries = new List();
    for (int i = 0; i < responseMap['countries_stat'].length; i++) {
      final inffectedCountry = responseMap['countries_stat'][i];

      var countryFound = _allCountries.firstWhere((country) {
        return country['name']
                    .toUpperCase()
                    .indexOf(inffectedCountry['country_name'].toUpperCase()) !=
                -1 ||
            country['altSpellings'].indexWhere(
                  (alt) =>
                      alt.toUpperCase().indexOf(
                          inffectedCountry['country_name'].toUpperCase()) !=
                      -1,
                ) !=
                -1;
      }, orElse: () => {});

      _inffectedCountries.add({
        ...inffectedCountry,
        'urlFlag': countryFound['flag'] != null ? countryFound['flag'] : '',
        'latlng':
            countryFound['latlng'] != null ? countryFound['latlng'] : [0, 0],
        'altSpellings': countryFound['altSpellings'] != null
            ? countryFound['altSpellings']
            : []
      });
    }

    setState(() {
      inffectedCountries = _inffectedCountries;
      inffectedCountriesFiltered = _inffectedCountries;
      updatedAt = responseMap['statistic_taken_at'];
      // filteredNames = names;
    });
  }

  void searchPressed() {
    setState(() {
      if (this.searchIcon.icon == Icons.search) {
        this.searchIcon = new Icon(Icons.close);
        this.appBarTitle = new TextField(
          controller: _filter,
          decoration: new InputDecoration(
              prefixIcon: new Icon(Icons.search), hintText: 'Search...'),
        );
      } else {
        this.searchIcon = new Icon(Icons.search);
        this.appBarTitle = new Text('COVID 19');
        inffectedCountriesFiltered = inffectedCountries;
        _filter.clear();
      }
    });
  }

  double zoomVal = 5.0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildBar(context),
      body: Stack(
        children: <Widget>[
          _buildGoogleMap(context),
          _zoomplusfunction(),
          _zoomminusfunction(),
          _buildContainer(),
        ],
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    return new AppBar(centerTitle: true, title: appBarTitle, actions: <Widget>[
      new IconButton(
        icon: searchIcon,
        onPressed: searchPressed,
      ),
    ]);
  }

  Widget _zoomminusfunction() {
    return Align(
      alignment: Alignment.topRight,
      child: IconButton(
          icon: Icon(FontAwesomeIcons.searchMinus, color: Color(0xff6200ee)),
          onPressed: () {
            zoomVal--;
            _minus(zoomVal);
          }),
    );
  }

  Widget _zoomplusfunction() {
    return Align(
      alignment: Alignment.topLeft,
      child: IconButton(
          icon: Icon(FontAwesomeIcons.searchPlus, color: Color(0xff6200ee)),
          onPressed: () {
            zoomVal++;
            _plus(zoomVal);
          }),
    );
  }

  Future<void> _minus(double zoomVal) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(40.712776, -74.005974), zoom: zoomVal)));
  }

  Future<void> _plus(double zoomVal) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(40.712776, -74.005974), zoom: zoomVal)));
  }

  Widget _buildContainer() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 20.0),
        height: 150.0,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: <Widget>[..._listBoxes()],
        ),
      ),
    );
  }

  List<Widget> _listBoxes() {
    List<Widget> listBoxes = new List<Widget>();
    inffectedCountriesFiltered.forEach((country) {
      listBoxes.add(_boxes(
          country['country_name'],
          country['urlFlag'],
          double.parse(country['latlng'][0].toString().replaceAll(',', '.')),
          double.parse(country['latlng'][1].toString().replaceAll(',', '.')),
          country['cases'],
          country['deaths'],
          country['total_recovered']));
      listBoxes.add(SizedBox(width: 10.0));
    });

    return listBoxes;
  }

  Widget _boxes(String country_name, String urlFlag, double lat, double lng,
      String cases, String deaths, String total_recovered) {
    return GestureDetector(
      onTap: () {
        _gotoLocation(lat, lng);
      },
      child: Container(
        child: new FittedBox(
          child: Material(
              color: Colors.white,
              elevation: 14.0,
              borderRadius: BorderRadius.circular(24.0),
              shadowColor: Color(0x802196F3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    width: 180,
                    height: 200,
                    child: ClipRRect(
                      borderRadius: new BorderRadius.circular(24.0),
                      child: SvgPicture.network(
                        urlFlag,
                        fit: BoxFit.fitWidth,
                        placeholderBuilder: (context) => Padding(
                            padding: const EdgeInsets.all(70.0),
                            child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                  Container(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: detailsContainer(
                          country_name, cases, deaths, total_recovered),
                    ),
                  ),
                ],
              )),
        ),
      ),
    );
  }

  Widget detailsContainer(String country_name, String cases, String deaths,
      String total_recovered) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Container(
              child: Text(
            country_name,
            style: TextStyle(
                color: Color(0xff6200ee),
                fontSize: 24.0,
                fontWeight: FontWeight.bold),
          )),
        ),
        SizedBox(height: 5.0),
        Container(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Container(
                child: Text(
              "$cases",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 20.0,
              ),
            )),
            Container(
                child: Text(
              " casos",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 18.0,
              ),
            )),
          ],
        )),
        SizedBox(height: 5.0),
        Container(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Container(
                child: Text(
              "$deaths",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 20.0,
              ),
            )),
            Container(
                child: Text(
              " muertes",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 18.0,
              ),
            )),
          ],
        )),
        SizedBox(height: 5.0),
        Container(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Container(
                child: Text(
              "$total_recovered",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 20.0,
              ),
            )),
            Container(
                child: Text(
              " recuperados",
              style: TextStyle(
                color: Colors.black54,
                fontSize: 18.0,
              ),
            )),
          ],
        )),
      ],
    );
  }

  Widget _buildGoogleMap(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      child: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: CameraPosition(target: LatLng(0, 0), zoom: 3),
        onMapCreated: (GoogleMapController controller) {
          _controller.complete(controller);
        },
        markers: _listMarker(),
      ),
    );
  }

  Future<void> _gotoLocation(double lat, double long) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(lat, long),
      zoom: 5,
      tilt: 50.0,
      // bearing: 45.0,
    )));
  }

  Set<Marker> _listMarker() {
    Set<Marker> listMarkers = new Set<Marker>();
    inffectedCountriesFiltered.forEach((country) {
      listMarkers.add(countryMarker(
        country['country_name'],
        double.parse(country['latlng'][0].toString().replaceAll(',', '.')),
        double.parse(country['latlng'][1].toString().replaceAll(',', '.')),
      ));
    });

    return listMarkers;
  }

  Marker countryMarker(String country_name, double lat, double lng) {
    return Marker(
      markerId: MarkerId(country_name),
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: country_name),
      icon: BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueViolet,
      ),
    );
  }
}

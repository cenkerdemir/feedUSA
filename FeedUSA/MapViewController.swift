//
//  ViewController.swift
//  Feed NYC
//
//  Created by Flatiron School on 8/8/16.
//  Copyright © 2016 Flatiron School. All rights reserved.
//

import UIKit
import GoogleMaps
import NVActivityIndicatorView


class MapViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate, SWRevealViewControllerDelegate {

    
    @IBOutlet weak var menuButton: UIBarButtonItem!
    
    // view and manager to operate with map
    let locationManager = CLLocationManager()
    var mapView: GMSMapView!
    var marker: GMSMarker!
    var button: UIButton!
    var facilityForTappedMarker = Facility()
    
    // closest location to current location
    //var closestFacility: Facility?
 //   var distanceInMetersForClosestFacility = 0.0
    
    // data store for all facility objects
    let store = FacilityDataStore.sharedInstance
    
    // Animation in center when loading map
    var activityIndicator: NVActivityIndicatorView!
    
    var gestTapRec = UITapGestureRecognizer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.addBigRedButton()
        self.store.readInTextFile()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        self.createMapView()
        self.addLoadingAnimation()
        // completion block, wait when all markers created
        self.setupMarkers { completion in
            if completion {
                OperationQueue.main.addOperation({
                    self.activityIndicator.stopAnimation()
                })
            }
        }

        self.view.addSubview(mapView)
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            self.view.addSubview(button)
        }
        self.view.addSubview(activityIndicator)
        
        mapView.delegate = self
        
        if self.revealViewController() != nil {
            menuButton.target = self.revealViewController()

            menuButton.action = #selector(SWRevealViewController.revealToggle(_:))
            //self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
            self.view.addGestureRecognizer(self.revealViewController().tapGestureRecognizer())
            self.revealViewController().toggleAnimationType = .spring //.EaseOut

        }
        self.mapView.settings.consumesGesturesInView = false
        self.revealViewController().delegate = self
        
        self.findClosestLocation()
    }
    

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    // finds the closest facility to current user location
    // puts closest location to the propert "closestFacility" and the distance to it in "distanceInMetersForClosestFacility"
    func findClosestLocation() {
        
        let currentLocation: CLLocation = CLLocation.init(latitude: self.store.currentLocationCoordinates.latitude, longitude: self.store.currentLocationCoordinates.longitude)
        var minDistance: Double = 100000000000.0
        var distanceInMeters = 0.0
        // go through all locations and find the closest one
        for i in 0..<store.facilities.count {
            let location = CLLocation.init(latitude: self.store.facilities[i].latitude, longitude: self.store.facilities[i].longitude)
                distanceInMeters = currentLocation.distance(from: location)
            if minDistance > distanceInMeters {
                minDistance = distanceInMeters
                self.store.closestFacility = self.store.facilities[i]
               // self.distanceInMetersForClosestFacility = minDistance
            }
            //convert the distance to miles
            self.store.facilities[i].distanceFromCurrentLocation = distanceInMeters * 0.000621371
        }
    }
    
    // MARK: -Displays all the pins on map
    func setupMarkers(_ completion:(Bool) -> ()) {
        self.activityIndicator.startAnimation()
        
        for i in 0..<self.store.facilities.count {
            let currentFacility = self.store.facilities[i]
            let position = CLLocationCoordinate2DMake(currentFacility.latitude, currentFacility.longitude)
            let marker = GMSMarker(position: position)
            marker.icon = GMSMarker.markerImage(with: UIColor.flatRed())
            marker.title = currentFacility.name
            
            let featureSet: Set<String> = Set(currentFacility.featureList)
            marker.snippet = featureSet.joined(separator: ". ") + "\n" + currentFacility.hoursOfOperation
            
            OperationQueue.main.addOperation({
                marker.map = self.mapView
                if currentFacility.featureList.contains("Food Pantry") && currentFacility.featureList.contains("Soup Kitchen") {
                    marker.icon = GMSMarker.markerImage(with: UIColor.flatPurple())
                } else if currentFacility.featureList.contains("Food Pantry") {
                    marker.icon = GMSMarker.markerImage(with: UIColor.flatGreenColorDark())
                }
                marker.infoWindowAnchor = CGPoint(x: 0.4, y: 0.3)
            })
        }
        completion(true)
    }
    
    func createMapView() {
        let smallerRect = CGRect(x: 0, y: Constants.navBarHeight, width: self.view.bounds.width, height: self.view.bounds.height - Constants.navBarHeight)
//        if CLLocationManager.authorizationStatus().hashValue == 0 { return }
//        print(CLLocationManager.authorizationStatus())
//        print (CLLocationManager.authorizationStatus().rawValue)
//        print (CLAuthorizationStatus.NotDetermined.rawValue)
//        
        
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedWhenInUse {
            
            //if the location is authorized, update the current location info in the data store everytime the view is loaded
            if let managerLocation = locationManager.location {
                self.store.currentLocationCoordinates.latitude = managerLocation.coordinate.latitude
                self.store.currentLocationCoordinates.longitude = managerLocation.coordinate.longitude
            }
            
            if self.IsUserInVicinityOfNewYork() == true {
            // setting map with current location ≥coordinats in the middle
                self.placeCameraToCurrentLocation(smallerRect)
            }
            else {
                self.placeCameraToTimeSquare(smallerRect)
            }
            self.view.addSubview(button)
        }
        else {
            self.placeCameraToTimeSquare(smallerRect)
            button.removeFromSuperview()
        }
        
    }
    
    // this should check if the user is close enough to any of the facilities, so the center of the app would be the user's current location. Otherwise, it will be Time Square
    func IsUserInVicinityOfNewYork() -> Bool {
       
        let eightmiles = 8.0
        guard let closestFacility = self.store.closestFacility else {
            print("could not get the closest facility from the store for comparison")
            return false
        }
        if closestFacility.distanceFromCurrentLocation < eightmiles {
            return true
        }
        else {
            return false
        }
    }
    
    // makes the center of the map Time Square (if the user declines location information access or she/he is far from the NY area)
    func placeCameraToTimeSquare(_ smallerRect: CGRect) {
        let camera = GMSCameraPosition.camera(withLatitude: 40.758896, longitude: -73.985130, zoom: Constants.midtownZoomLevel)
        self.mapView = GMSMapView.map(withFrame: smallerRect, camera: camera)
        self.mapView.isMyLocationEnabled = false
        // button in right low corner that makes current location in the middle
        self.mapView.settings.myLocationButton = false
    }
    
    // makes the center of the map the current location of the user (if the user is close to the area)
    func placeCameraToCurrentLocation(_ smallerRect: CGRect) {
        if let managerLocation = locationManager.location {
            self.store.currentLocationCoordinates.latitude = managerLocation.coordinate.latitude
            self.store.currentLocationCoordinates.longitude = managerLocation.coordinate.longitude
        }
        let camera = GMSCameraPosition.camera(withLatitude: self.store.currentLocationCoordinates.latitude, longitude: self.store.currentLocationCoordinates.longitude, zoom: Constants.defaultZoomLevel)
        self.mapView = GMSMapView.map(withFrame: smallerRect, camera: camera)
        self.mapView.isMyLocationEnabled = true
        // button in right low corner that makes current location in the middle
        self.mapView.settings.myLocationButton = true
    }

    // Sets properties of "get nearby help" button
    func addBigRedButton() {
        button = UIButton()
        button.setTitle("FIND NEAREST", for: UIControlState())
        button.setTitleColor(UIColor.flatWhite(), for: UIControlState())
        button.backgroundColor = UIColor.flatNavyBlue().lighten(byPercentage: 0.1)
        button.addTarget(self, action: #selector(MapViewController.helpButtonTapped(_:)), for: .touchUpInside)
        button.frame = CGRect(x: 170, y: 450, width: 220, height: 30)
        button.layer.cornerRadius = 11.5 //Rounded edge of button: 20 is a semi-circle
        button.layer.borderColor = UIColor.flatBlack().cgColor
        
        //UIScreen.mainScreen().bounds.size.width / 2.0
        button.center = CGPoint(x: self.view.frame.midX, y: self.view.frame.height - 80)
        // width is 295
        //153 490 295 40
    }
    
    func helpButtonTapped(_ sender: UIButton!) {
        let cenkersStoryboard = UIStoryboard(name: "CenkersStoryboard", bundle: nil)
        
        let detailVC = cenkersStoryboard.instantiateViewController(withIdentifier: "CenkersDetailViewController") as! CenkersDetailViewController
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            if let managerLocation = locationManager.location {
                self.store.currentLocationCoordinates.latitude = managerLocation.coordinate.latitude
                self.store.currentLocationCoordinates.longitude = managerLocation.coordinate.longitude
            }
        }
        //call the function that updates the closest facility property before using the facility
        self.findClosestLocation()
        
        if let closestFacility = self.store.closestFacility {
            detailVC.facilityToDisplay = closestFacility
        }
        else {
            print("could not unwrap the closest facility")
        }
        
        self.present(detailVC, animated: true, completion: nil)
    }
    
    // Sets properties of loading animation while markers are generated
    func addLoadingAnimation() {
        let animationFrame = CGRect(x: self.mapView.frame.midX - Animation.halfSizeOffset, y: self.mapView.frame.midY - Animation.halfSizeOffset,
                                        width: Animation.width, height: Animation.height)
        
        self.activityIndicator = NVActivityIndicatorView(frame: animationFrame,
                                                         type: NVActivityIndicatorType.ballScaleRippleMultiple,
                                                         color: UIColor.white,
                                                         padding: 0.0)
        
        //       NVActivityIndicatorType.BallScaleRippleMultiple
        // ALSO  NVActivityIndicatorType.BallClipRotateMultiple  is great!
    }


    
}

// MARK: - CLLocationManagerDelegate

extension MapViewController {
    
    // 2 authorization status for the application (can I get access to your location?)
    @objc(locationManager:didChangeAuthorizationStatus:) func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        
        // if user aggried access to his/he location coordinats
        if status == .authorizedWhenInUse {
            
            // ask for updates on the user’s location
            locationManager.startUpdatingLocation()
            
            
            // current user location latitude and longitude
            if let managerLocation = manager.location {
                self.store.currentLocationCoordinates.latitude = managerLocation.coordinate.latitude
                self.store.currentLocationCoordinates.longitude = managerLocation.coordinate.longitude
                self.findClosestLocation()
            }
            else {
                print("could not get the current location from the location manager")
            }
            
            if self.IsUserInVicinityOfNewYork() == true {
                //calling the function that updates the singleton with current coordinates
                let camera = GMSCameraPosition.camera(withLatitude: self.store.currentLocationCoordinates.latitude, longitude: self.store.currentLocationCoordinates.longitude, zoom: Constants.defaultZoomLevel)
                mapView.camera = camera
                mapView.isMyLocationEnabled = true
            
                // button in right low corner that makes current location in the middle
                self.mapView.settings.myLocationButton = true
            
                //self.mapView.addSubview(button)
            }
            else {
                let camera = GMSCameraPosition.camera(withLatitude: 40.758896, longitude: -73.985130, zoom: Constants.midtownZoomLevel)
                mapView.camera = camera
                mapView.isMyLocationEnabled = false
                // button in right low corner that makes current location in the middle
                self.mapView.settings.myLocationButton = false
            }
            self.view.addSubview(button)
        }
        if status == .denied {
            // Let them know they need to allow location!
            let camera = GMSCameraPosition.camera(withLatitude: 40.758896, longitude: -73.985130, zoom: Constants.midtownZoomLevel)
            mapView.camera = camera
            mapView.isMyLocationEnabled = false
            showLocationAlert()
            // button in right low corner that makes current location in the middle
            self.mapView.settings.myLocationButton = false
            
            button.removeFromSuperview()
        }
        
    }
    

    //function to set the current coordinates to singleton's (datastore) currenLocationCoordinates property
//    func updateCurrentLocation() {
//        let currentCoordinates = CLLocationCoordinate2D(latitude: self.currentDeviceLocationLatitude, longitude: self.currentDeviceLocationLongitude)
//        
//        store.currentLocationCoordinates = currentCoordinates
//    }
    

    // this function moves blue marker on the map with user movement,
    // constantly updating new user location and move map accordingly, so blue marker always in the middle of the view
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            if self.IsUserInVicinityOfNewYork() == true {
                mapView.camera = GMSCameraPosition(target: location.coordinate, zoom: Constants.defaultZoomLevel, bearing: 0, viewingAngle: 0)
                mapView.isMyLocationEnabled = true
                
                // button in right low corner that makes current location in the middle
                self.mapView.settings.myLocationButton = true
            }
            else {
                let camera = GMSCameraPosition.camera(withLatitude: 40.758896, longitude: -73.985130, zoom: Constants.midtownZoomLevel)
                mapView.camera = camera
            }
            locationManager.stopUpdatingLocation()
        }
    }
    
    @objc(mapView:didTapMarker:) func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker)-> Bool {
        if marker != mapView.selectedMarker {
            mapView.selectedMarker = marker
        }
        return true
    }
    
    func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
        let customInfoWindow : CustomInfoWindow!
        customInfoWindow = CustomInfoWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 180))
        //NSBundle.mainBundle().loadNibNamed("CustomInfoWindow", owner: self, options: nil)[0] as! CustomInfoWindow
        customInfoWindow.nameButtonLabel.setTitle("\(marker.title!)\n\(marker.snippet!)", for: UIControlState())
        
        let currentZoomLevel = mapView.camera.zoom
        mapView.camera = GMSCameraPosition(target: marker.position, zoom: currentZoomLevel, bearing: 0, viewingAngle: 0)
        return customInfoWindow
    }
    
    @objc(mapView:didTapInfoWindowOfMarker:) func mapView(_ mapView: GMSMapView, didTapInfoWindowOf marker: GMSMarker) {
        self.facilityForTappedMarker = self.findFacilityForMarker(marker)
        performSegue(withIdentifier: "detailSegue", sender: mapView)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "detailSegue" {
            let detailVC = segue.destination as! CenkersDetailViewController
            detailVC.facilityToDisplay = self.facilityForTappedMarker
        }
    }
    
    func findFacilityForMarker(_ marker: GMSMarker) -> Facility {
        let facilities = store.facilities.filter{ $0.name == marker.title && $0.latitude == marker.layer.latitude && $0.longitude == marker.layer.longitude}
        return facilities[0]
    }
    
    func showLocationAlert() {
        let alert = UIAlertController(title: "Location Permission", message: "Please allow our app to see your location while in use so we can serve you better. You can change the permissions in your phone's settings.", preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(OKAction)
        present(alert, animated: true, completion: nil)
    }
    
}

// MARK: - SWRevealViewControllerDelegate
extension MapViewController {
    @objc(revealController:willMoveToPosition:) func revealController(_ revealController: SWRevealViewController!, willMoveTo position: FrontViewPosition) {
        if position == .left {
            // happens when map disappears and were going to the TableView list
            // Map is visible
            self.mapView.settings.scrollGestures = true
        }
        if position == .right {
            // In Menu Panel
            // Turn off touching map view
            self.mapView.settings.scrollGestures = false
        }
    }
    /*
    func revealController(revealController: SWRevealViewController!, panGestureBeganFromLocation location: CGFloat, progress: CGFloat) {
        // Started dragging out the menu
        if location == 0.0 {
            //print("dragging out the menu")
           self.mapView.settings.scrollGestures = false

        }
    }
    func revealController(revealController: SWRevealViewController!, panGestureEndedToLocation location: CGFloat, progress: CGFloat) {
        // Possible bad swipe. User likely tried to swipe open the menu and failed
        if progress < 0.5 || progress > 1.0 {
            self.mapView.settings.scrollGestures = true
        }
    }
    */
}


import Foundation
import SwiftUI
import CoreLocation
import GoogleMaps

class DirectionsFuncts: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var mapView: GMSMapView?

    let locationManager = CLLocationManager()
    let speech = SpeechFuncts()

    // get user long & lat
    var userLocation: CLLocationCoordinate2D?

    var placeResults: [[String: Any]] = []
    var currentPlaceIndex = 0

    // for navigation
    var navigationSteps: [[String: Any]] = []
    var currentStepIx = 0
    var nextStepCoord: CLLocationCoordinate2D?

    let googleAPIKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String ?? ""

    func setupLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: Location Updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        userLocation = location.coordinate

        if mapView == nil {
            let camera = GMSCameraPosition.camera(
                withLatitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                zoom: 15
            )
            mapView = GMSMapView(frame: .zero, camera: camera)
            mapView?.isMyLocationEnabled = true
        } else {
            let cameraUpdate = GMSCameraUpdate.setTarget(location.coordinate)
            mapView?.animate(with: cameraUpdate)
        }
        // for navigation, update next step if we're close to it
        if let nextCoord = nextStepCoord {
            let userLoc = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            let stepLoc = CLLocation(latitude: nextCoord.latitude, longitude: nextCoord.longitude)

            let distance = userLoc.distance(from: stepLoc)
            // within 20 meters of the next step, load the next one
            if distance < 20 { 
                if currentStepIx < navigationSteps.count - 1{
                    currentStepIx += 1
                    loadNextStep()
                }
            }
        }  
    }

    // MARK: Start Voice Search
    func startListening() {
        speech.speak("Where would you like to go?")
        speech.startListening { query in
            self.searchDestination(query: query)
        }
    }

    // MARK: Search Destination
    func searchDestination(query: String) {
        guard let location = userLocation else {
            speech.speak("Unable to get your location. Please try again.")
            return
        }
        // Google Places API Text Search to find locations matching the query near the user
        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&location=\(location.latitude),\(location.longitude)&radius=5000&key=\(googleAPIKey)"

        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in

            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        DispatchQueue.main.async {
                            self.placeResults = results
                            self.currentPlaceIndex = 0
                            self.showNextLocation()
                        }
                    }
                } catch {
                    print("JSON parsing error: \(error.localizedDescription)")
                }
            } else if let error = error {
                print("Network error: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: Show Next Location
    func showNextLocation() {
        guard !placeResults.isEmpty else {
            speech.speak("No more results found.")
            return
        }

        if currentPlaceIndex >= placeResults.count {
            speech.speak("No more results found.")
            return
        }
        let place = placeResults[currentPlaceIndex]
        guard
            let name = place["name"] as? String,
            let geometry = place["geometry"] as? [String: Any],
            let location = geometry["location"] as? [String: Any],
            let latitude = location["lat"] as? CLLocationDegrees,
            let longitude = location["lng"] as? CLLocationDegrees,
            let userLoc = userLocation
        else { return }

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapView?.clear()

        let marker = GMSMarker(position: coordinate)
        marker.title = name
        marker.map = mapView

        let cameraUpdate = GMSCameraUpdate.setTarget(coordinate, zoom: 15)
        mapView?.animate(with: cameraUpdate)

        let distanceMiles = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude).distance(from: CLLocation(latitude: latitude, longitude: longitude)) / 1609.34

        speech.speak("\(name) is \(String(format: "%.2f", distanceMiles)) miles away. Would you like to go there?")
    }

    // MARK: Handle User Response
    func userResponse(_ response: String){
        let lowerResponse = response.lowercased()

        if lowerResponse.contains("yes") {
            if currentPlaceIndex < placeResults.count {
                let place = placeResults[currentPlaceIndex]

                if let geometry = place["geometry"] as? [String: Any],
                   let location = geometry["location"] as? [String: Any],
                   let latitude = location["lat"] as? CLLocationDegrees,
                   let longitude = location["lng"] as? CLLocationDegrees {

                    let destination = CLLocationCoordinate2D(
                        latitude: latitude,
                        longitude: longitude
                    )
                    startNavigation(to: destination)
                }
            }
        } else if lowerResponse.contains("no") {
            currentPlaceIndex += 1
            showNextLocation()

        } else if lowerResponse.contains("cancel") {
            speech.speak("Navigation cancelled.")

        } else {
            speech.speak("yes, no, or cancel.")
        }
    }

    // MARK: Start Navigation
    func startNavigation(to destination: CLLocationCoordinate2D) {
        guard let userLoc = userLocation else {
            speech.speak("Unable to get your location. Please try again.")
            return
        }

        let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(userLoc.latitude),\(userLoc.longitude)&destination=\(destination.latitude),\(destination.longitude)&mode=walking&key=\(googleAPIKey)"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let routes = json["routes"] as? [[String: Any]],
                       let firstRoute = routes.first,
                       let legs = firstRoute["legs"] as? [[String: Any]],
                       let firstLeg = legs.first,
                       let steps = firstLeg["steps"] as? [[String: Any]] {
                        
                        DispatchQueue.main.async {
                            self.navigationSteps = steps
                            self.currentStepIx = 0
                            self.speech.speak("Starting navigation to your destination.")
                            self.loadNextStep()
                        }
                    }
                } catch {
                    print("JSON parsing error: \(error.localizedDescription)")
                }
            } else if let error = error {
                print("Network error: \(error.localizedDescription)")
            }
        }.resume()
    }

    // MARK: Load Next Step for step by step navigation
    func loadNextStep() {
        if currentStepIx >= navigationSteps.count {
            speech.speak("You have arrived at your destination.")
            return
        }

        let step = navigationSteps[currentStepIx]

        guard
            let endLocation = step["end_location"] as? [String: Any],
            let lat = endLocation["lat"] as? CLLocationDegrees,
            let lng = endLocation["lng"] as? CLLocationDegrees,
            let userLoc = userLocation
        else { return }

        nextStepCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        // need to strip html fields into plain text for speech output
        if let instructions = step["html_instructions"] as? String {
            let cleanInstructions = instructions.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

            let userLocationObj = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            let stepLocationObj = CLLocation(latitude: lat, longitude: lng)
            let distanceMeters = userLocationObj.distance(from: stepLocationObj)
            let distanceFeet = Int(distanceMeters * 3.28084)

            speech.speak("\(cleanInstructions) in \(distanceFeet) feet.")
        }
    }
}

import Foundation
import SwiftUI
import CoreLocation
import GoogleMaps

class DirectionsFuncts: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var mapView: GMSMapView?
    @Published var recognizedSpeech: String = ""
    @Published var debugMessage: String = "Idle"
    @Published var selectedPlaceName: String = ""
    var hasHandledSpeechResult = false
    @Published var currentInstruction: String = ""
    private var lastSpokenInstruction: String = ""
    
    private let speech = SpeechFuncts()

    let locationManager = CLLocationManager()

    // get user long & lat
    var userLocation: CLLocationCoordinate2D?

    var placeResults: [[String: Any]] = []
    var currentPlaceIndex = 0

    // for navigation
    var navigationSteps: [[String: Any]] = []
    var currentStepIx = 0
    var nextStepCoord: CLLocationCoordinate2D?
    
    var onResultReady: (() -> Void)?
    var onNavigationStart: (() -> Void)?
    var onNavigationEnd: (() -> Void)?

    let googleAPIKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_API_KEY") as? String ?? ""

    func setupLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        if mapView == nil {
            let camera = GMSCameraPosition.camera(
                withLatitude: 33.883,
                longitude: -117.885,
                zoom: 14
            )

            let options = GMSMapViewOptions()
            options.camera = camera
            options.frame = .zero

            mapView = GMSMapView(options: options)
            mapView?.isMyLocationEnabled = true
            mapView?.settings.myLocationButton = true
        }
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
            
            let options = GMSMapViewOptions()
            options.camera = camera
            options.frame = .zero

            mapView = GMSMapView(options: options)
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
        hasHandledSpeechResult = false
        recognizedSpeech = ""
        selectedPlaceName = ""
        debugMessage = "Listening..."

        speech.speak("Where would you like to go?")
        speech.startListening { [weak self] query in
            guard let self else { return }

            DispatchQueue.main.async {
                guard !self.hasHandledSpeechResult else { return }

                let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    self.debugMessage = "No speech detected"
                    return
                }

                self.hasHandledSpeechResult = true
                self.recognizedSpeech = cleaned
                self.debugMessage = "Recognized: \(cleaned)"
                self.searchDestination(query: cleaned)
            }
        }
    }
    
    // MARK: Search Destination
    func searchDestination(query: String) {
        guard let location = userLocation else {
            DispatchQueue.main.async {
                self.debugMessage = "No user location available"
            }
            speech.speak("Unable to get your location. Please try again.")
            return
        }

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://maps.googleapis.com/maps/api/place/textsearch/json?query=\(encodedQuery)&location=\(location.latitude),\(location.longitude)&radius=5000&key=\(googleAPIKey)"

        DispatchQueue.main.async {
            self.debugMessage = "Searching for: \(query)"
            print("DEBUG recognized query:", query)
            print("DEBUG places url:", urlString)
        }

        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.debugMessage = "Invalid Places URL"
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.debugMessage = "Network error: \(error.localizedDescription)"
                    print("DEBUG network error:", error.localizedDescription)
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.debugMessage = "No data returned from Places API"
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("DEBUG places response:", json)

                    let status = json["status"] as? String ?? "UNKNOWN"
                    let results = json["results"] as? [[String: Any]] ?? []

                    let sortedResults = results.sorted { a, b in
                        guard
                            let aGeo = a["geometry"] as? [String: Any],
                            let aLoc = aGeo["location"] as? [String: Any],
                            let aLat = aLoc["lat"] as? CLLocationDegrees,
                            let aLng = aLoc["lng"] as? CLLocationDegrees,

                            let bGeo = b["geometry"] as? [String: Any],
                            let bLoc = bGeo["location"] as? [String: Any],
                            let bLat = bLoc["lat"] as? CLLocationDegrees,
                            let bLng = bLoc["lng"] as? CLLocationDegrees
                        else {
                            return false
                        }

                        let userCLLocation = CLLocation(
                            latitude: location.latitude,
                            longitude: location.longitude
                        )

                        let aDistance = userCLLocation.distance(
                            from: CLLocation(latitude: aLat, longitude: aLng)
                        )

                        let bDistance = userCLLocation.distance(
                            from: CLLocation(latitude: bLat, longitude: bLng)
                        )

                        return aDistance < bDistance
                    }

                    DispatchQueue.main.async {
                        self.placeResults = sortedResults
                        self.currentPlaceIndex = 0
                        self.debugMessage = "Places status: \(status), results: \(sortedResults.count)"
                    }

                    if results.isEmpty {
                        DispatchQueue.main.async {
                            self.selectedPlaceName = ""
                            self.onResultReady?()
                        }
                        self.speech.speak("I could not find any matching places.")
                    } else {
                        DispatchQueue.main.async {
                            self.showNextLocation()
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.debugMessage = "JSON parsing error: \(error.localizedDescription)"
                    print("DEBUG JSON parsing error:", error.localizedDescription)
                }
            }
        }.resume()
    }

    // MARK: Show Next Location
    func showNextLocation() {
        guard !placeResults.isEmpty else {
            debugMessage = "No results to show"
            selectedPlaceName = ""
            onResultReady?()
            speech.speak("No more results found.")
            return
        }

        if currentPlaceIndex >= placeResults.count {
            debugMessage = "Reached end of results"
            selectedPlaceName = ""
            onResultReady?()
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
        else {
            debugMessage = "Malformed place result"
            return
        }

        selectedPlaceName = name
        debugMessage = "Showing result \(currentPlaceIndex + 1) of \(placeResults.count): \(name)"
        print("DEBUG showing place:", name, latitude, longitude)

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        mapView?.clear()

        let marker = GMSMarker(position: coordinate)
        marker.title = name
        marker.map = mapView

        let cameraUpdate = GMSCameraUpdate.setTarget(coordinate, zoom: 15)
        mapView?.animate(with: cameraUpdate)

        let distanceMiles =
            CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
            .distance(from: CLLocation(latitude: latitude, longitude: longitude)) / 1609.34

        onResultReady?()

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
            if let error = error {
                DispatchQueue.main.async {
                    self.debugMessage = "Directions network error: \(error.localizedDescription)"
                }
                print("Network error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.debugMessage = "No data returned from Directions API"
                }
                return
            }

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
                        self.nextStepCoord = nil
                        self.currentInstruction = ""
                        self.lastSpokenInstruction = ""

                        self.debugMessage = "Navigation started with \(steps.count) steps"

                        self.onNavigationStart?()

                        self.speech.speak("Starting navigation to your destination.")
                        self.loadNextStep()
                    }
                } else {
                    DispatchQueue.main.async {
                        self.debugMessage = "No route found"
                        self.speech.speak("I could not find a route to that destination.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.debugMessage = "Directions JSON parsing error: \(error.localizedDescription)"
                }
                print("JSON parsing error: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func speakInstruction(_ instruction: String) {
        let cleaned = instruction.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { return }
        guard cleaned != lastSpokenInstruction else { return }

        currentInstruction = cleaned
        lastSpokenInstruction = cleaned

        speech.speak(cleaned)
    }

    // MARK: Load Next Step for step by step navigation
    func loadNextStep() {
        guard currentStepIx < navigationSteps.count else {
            currentInstruction = "You have arrived at your destination."
            speech.speak("You have arrived at your destination.")
            onNavigationEnd?()
            return
        }

        let step = navigationSteps[currentStepIx]

        guard
            let endLocation = step["end_location"] as? [String: Any],
            let lat = endLocation["lat"] as? CLLocationDegrees,
            let lng = endLocation["lng"] as? CLLocationDegrees,
            let userLoc = userLocation
        else {
            debugMessage = "Could not load navigation step"
            return
        }

        nextStepCoord = CLLocationCoordinate2D(latitude: lat, longitude: lng)

        guard let htmlInstructions = step["html_instructions"] as? String else {
            debugMessage = "Missing step instructions"
            return
        }

        let cleanInstructions = htmlInstructions
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "and")

        let userLocationObj = CLLocation(
            latitude: userLoc.latitude,
            longitude: userLoc.longitude
        )
        
        let stepLocationObj = CLLocation(
            latitude: lat,
            longitude: lng
        )

        let distanceMeters = userLocationObj.distance(from: stepLocationObj)
        let distanceFeet = Int(distanceMeters * 3.28084)

        let spokenText = "\(cleanInstructions) in \(distanceFeet) feet."

        debugMessage = "Step \(currentStepIx + 1) of \(navigationSteps.count): \(spokenText)"

        speakInstruction(spokenText)
    }

}

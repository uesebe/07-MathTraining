//
//  ViewController.swift
//  07-MathTraining
//
//  Created by Cristian Torres on 1/30/19.
//  Copyright © 2019 Uesebe. All rights reserved.
//

import UIKit
import Vision

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var drawingView: DrawingImageView!
    
    @IBOutlet weak var progressView: UIProgressView!
    
    let factory = QuestionsFactory()
    var mnistModel = MnistModel()
    var gameTimer : Timer!
    var timeLeft : Int = 0
    var totalTime = 600
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
       drawingView.delegate = self
        
        title = "Preguntas matemáticas"
        tableView.layer.borderColor = UIColor.lightGray.cgColor
        tableView.layer.borderWidth = 1
        
        self.restartGame(action: nil)
    }
    
    func numberDrawn(_ image: UIImage){
        
        //1. Redimensionar la imagen del usuario a una imagen 299 x 299 (tamaño que espera el modelo)
        let modelSize = 299
        UIGraphicsBeginImageContextWithOptions(CGSize(width: modelSize, height: modelSize), true, 1.0)
        image.draw(in: CGRect(x: 0, y: 0, width: modelSize, height: modelSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        //2. UIImage -> CIImage
        guard let ciImage = CIImage(image: newImage) else {
            fatalError("Error al convertir de UIImage a CIImage")
        }
        //3. Cargar el modelo en Vision
        guard let model = try? VNCoreMLModel(for: mnistModel.model) else {
            fatalError("No se ha podido preparar el modelo de clasificación para Vision")
        }
        
        //4. Petición de VNCoreMLRequest
        let request = VNCoreMLRequest(model: model) { [weak self] (request, error) in
            //5. Al detectar la imagen, tenemos que saber el nuúmero que ha escrito el usuario y validar la respuesta
            
            guard let results = request.results as? [VNClassificationObservation], let prediction = results.first else {
                fatalError("Error al hacer la predicción: \(error?.localizedDescription ?? "Error desconocido")")
            }
            
            DispatchQueue.main.async {
                //El resultado es la etiqueta de la clase donde el modeloo ha catalogado nuestra imagen
                let result = Int(prediction.identifier) ?? 0
                //Asignamos la respuesta del usuario a la pregunta actual
                self?.factory.updateQuestion(at: 0, with: result)
                //Actualizar la celda
                self?.tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                //Validamos si la respuuesta es correcta
                self?.factory.validateQuestion(at: 0)
                //Creamos una nueva pregunta
                self?.askNewQuestion()
            }
            
        }
        
        //6. Juntar todo en un VNImageRequestHandler
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        //Ejecutamos la predicción en un hilo secundario para no bloquear la UI
        DispatchQueue.global(qos: .userInteractive).async {
            do{
                try handler.perform([request])
            }catch{
                print(error.localizedDescription)
            }
        }
    }
    
    func askNewQuestion(){
        drawingView.image = nil
        
        if (timeLeft > 0) {
            factory.addNewQuestion()
            
            let newIndexPath = IndexPath(row: 0, section: 0)
            tableView.insertRows(at: [newIndexPath], with: .right)
            
            let secondIndexPath = IndexPath(row: 1, section: 0)
            if let cell = tableView.cellForRow(at: secondIndexPath), let question = factory.getQuestionAt(position: 1){
                setText(for: cell, at: secondIndexPath, to: question)
            }
        }else {
            
            gameTimer.invalidate()
            
            let controller = UIAlertController(title: "Fin del juego", message: "Has conseguido \(self.factory.score) / \(self.factory.numberOfQuestions() * self.factory.pointsPerQuestion) puntos", preferredStyle: .alert)
            let action = UIAlertAction(title: "Jugar otra vez", style: .default, handler: restartGame)
            controller.addAction(action)
            present(controller, animated: true)
        }
    }
    
    func setText(for cell: UITableViewCell, at indexPath: IndexPath, to question:Question){
        if indexPath.row == 0 {
            cell.textLabel?.font = UIFont.boldSystemFont(ofSize: 36)
        } else{
            cell.textLabel?.font = UIFont.systemFont(ofSize: 18)
            if question.answer == question.userAnswer {
                cell.backgroundColor = UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 0.25)
            }else {
                cell.backgroundColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.25)
            }
        }
        if let userAnswer = question.userAnswer{
            cell.textLabel?.text = "\(question.text) = \(userAnswer)"
        }else{
            cell.textLabel?.text = "\(question.text) = ?"
        }
    }
    
    // - MARK: UITableViewDatasource methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return factory.numberOfQuestions()
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        if let currentQuestion = factory.getQuestionAt(position: indexPath.row){
            setText(for: cell, at: indexPath, to: currentQuestion)
        }
        return cell
    }
    
    // - MARK: UITableViewDelegaate Methods
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
    
    func restartGame(action:UIAlertAction?){
        factory.restartData()
        self.tableView.reloadData()
        
        timeLeft = totalTime
        
        self.progressView.progress = 1.0
        self.progressView.progressTintColor = UIColor.green
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer) in
            self.timeLeft -= 1
            
            self.progressView.progress = Float(max(self.timeLeft,0)) / Float(self.totalTime)
            //La cantidad de verde se va perdiendo  cuando queda menos tiempo
            let greenValue = CGFloat(Float(self.timeLeft)/Float(self.totalTime))
            //La cantidad de rojo va aumentando cuando queda menos tiempo
            let redValue = 1.0 - greenValue
            
            self.progressView.progressTintColor = UIColor(red: redValue, green: greenValue, blue: 0.0, alpha: 1.0)
        })
    }
}


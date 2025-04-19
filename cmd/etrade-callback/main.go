package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "3002"
	}

	etradeServiceURL := os.Getenv("ETRADE_SERVICE_URL")
	if etradeServiceURL == "" {
		etradeServiceURL = "http://etrade-service:8080"
	}

	http.HandleFunc("/etrade/callback", func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Received callback from E-Trade: %s", r.URL.String())

		// Extract the oauth_verifier and oauth_token from the query parameters
		verifier := r.URL.Query().Get("oauth_verifier")
		token := r.URL.Query().Get("oauth_token")

		if verifier == "" || token == "" {
			log.Printf("Missing required parameters: verifier=%s, token=%s", verifier, token)
			http.Error(w, "Missing required parameters", http.StatusBadRequest)
			return
		}

		// Display a success page with instructions for the user
		w.Header().Set("Content-Type", "text/html")
		w.WriteHeader(http.StatusOK)

		html := `
		<!DOCTYPE html>
		<html>
		<head>
			<title>E-Trade Authorization Successful</title>
			<style>
				body {
					font-family: Arial, sans-serif;
					margin: 0;
					padding: 20px;
					background-color: #f5f5f5;
				}
				.container {
					max-width: 600px;
					margin: 0 auto;
					background-color: white;
					padding: 20px;
					border-radius: 5px;
					box-shadow: 0 2px 4px rgba(0,0,0,0.1);
				}
				h1 {
					color: #2c3e50;
				}
				.code {
					background-color: #f8f9fa;
					padding: 10px;
					border-radius: 4px;
					font-family: monospace;
					margin: 10px 0;
				}
				.success {
					color: #28a745;
					font-weight: bold;
				}
			</style>
		</head>
		<body>
			<div class="container">
				<h1>E-Trade Authorization Successful</h1>
				<p class="success">Your E-Trade account has been successfully authorized.</p>
				<p>Please copy the verification code below and paste it into the TrustAInvest application:</p>
				<div class="code">%s</div>
				<p>You can close this window after copying the code.</p>
			</div>
		</body>
		</html>
		`

		fmt.Fprintf(w, html, verifier)
	})

	log.Printf("Starting E-Trade callback server on port %s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}

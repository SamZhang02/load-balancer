package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	if len(os.Args) < 2 {
		log.Fatal("usage: go run main.go <port>")
	}

	port := os.Args[1]

	mux := http.NewServeMux()
	mux.HandleFunc("/hello", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello from port %s\n", port)
	})

	addr := ":" + port
	log.Printf("backend listening on http://localhost%s\n", addr)

	log.Fatal(http.ListenAndServe(addr, mux))
}

package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v4/pgxpool"
)

// Document represents a document in the system
type Document struct {
	ID          string     `json:"id"`
	Type        string     `json:"type"`
	Title       string     `json:"title"`
	Description string     `json:"description,omitempty"`
	Status      string     `json:"status"`
	CreatorID   string     `json:"creator_id"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
	ExpiresAt   *time.Time `json:"expires_at,omitempty"`
	TemplateID  *string    `json:"template_id,omitempty"`
	Version     int        `json:"version"`
}

// File represents a file related to a document
type File struct {
	ID          string    `json:"id"`
	DocumentID  string    `json:"document_id"`
	FileKey     string    `json:"file_key"`
	FileName    string    `json:"file_name"`
	ContentType string    `json:"content_type"`
	SizeBytes   int64     `json:"size_bytes"`
	UploadedAt  time.Time `json:"uploaded_at"`
}

// Signatory represents someone who needs to sign a document
type Signatory struct {
	ID          string     `json:"id"`
	DocumentID  string     `json:"document_id"`
	UserID      string     `json:"user_id,omitempty"`
	Name        string     `json:"name"`
	Email       string     `json:"email"`
	Role        string     `json:"role"`
	SignedAt    *time.Time `json:"signed_at,omitempty"`
	SignatureID *string    `json:"signature_id,omitempty"`
	Order       int        `json:"order"`
	Required    bool       `json:"required"`
}

var db *pgxpool.Pool

func main() {
	log.Println("Starting document-service...")

	// Connect to database
	dbURL := "postgres://trustainvest:trustainvest@postgres:5432/trustainvest"
	var err error
	db, err = pgxpool.Connect(context.Background(), dbURL)
	if err != nil {
		log.Fatalf("Unable to connect to database: %v", err)
	}
	defer db.Close()

	// Verify database connection
	if err := db.Ping(context.Background()); err != nil {
		log.Fatalf("Unable to ping database: %v", err)
	}
	log.Println("Connected to database")

	// Set up Gin router
	router := gin.Default()

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"service": "document-service",
		})
	})

	// API routes
	v1 := router.Group("/api/v1")
	{
		// Documents
		documents := v1.Group("/documents")
		{
			documents.GET("", listDocuments)
			documents.GET("/:id", getDocumentByID)
			documents.POST("", createDocument)
			documents.PUT("/:id", updateDocument)
			documents.DELETE("/:id", deleteDocument)

			// Files
			documents.GET("/:id/files", getDocumentFiles)
			documents.POST("/:id/files", addDocumentFile)
			documents.DELETE("/:id/files/:fileId", removeDocumentFile)

			// Signatories
			documents.GET("/:id/signatories", getDocumentSignatories)
			documents.POST("/:id/signatories", addSignatory)
			documents.PUT("/:id/signatories/:signatoryId", updateSignatory)
			documents.DELETE("/:id/signatories/:signatoryId", removeSignatory)

			// Signing
			documents.POST("/:id/sign", signDocument)
		}

		// User documents
		userDocuments := v1.Group("/users/:userId/documents")
		{
			userDocuments.GET("", getUserDocuments)
		}

		// Templates
		templates := v1.Group("/templates")
		{
			templates.GET("", listTemplates)
			templates.GET("/:id", getTemplateByID)
			templates.POST("", createTemplate)
			templates.PUT("/:id", updateTemplate)

			// Generate document from template
			templates.POST("/:id/generate", generateDocument)
		}
	}

	// Start server
	srv := &http.Server{
		Addr:    ":8080",
		Handler: router,
	}

	// Run server in a goroutine
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal to gracefully shut down
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down document-service...")

	// Give the server 5 seconds to finish ongoing requests
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}

	log.Println("Document service stopped")
}

// Documents handlers
func listDocuments(c *gin.Context) {
	var documents []Document
	rows, err := db.Query(context.Background(), `
		SELECT id, type, title, description, status, creator_id,
		       created_at, updated_at, expires_at, template_id, version
		FROM documents.documents
		WHERE status != 'DELETED'
		LIMIT 100
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve documents"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var document Document
		err := rows.Scan(
			&document.ID, &document.Type, &document.Title, &document.Description,
			&document.Status, &document.CreatorID, &document.CreatedAt,
			&document.UpdatedAt, &document.ExpiresAt, &document.TemplateID,
			&document.Version,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan document data"})
			return
		}
		documents = append(documents, document)
	}

	c.JSON(http.StatusOK, gin.H{"documents": documents})
}

func getDocumentByID(c *gin.Context) {
	id := c.Param("id")
	var document Document

	err := db.QueryRow(context.Background(), `
		SELECT id, type, title, description, status, creator_id,
		       created_at, updated_at, expires_at, template_id, version
		FROM documents.documents
		WHERE id = $1 AND status != 'DELETED'
	`, id).Scan(
		&document.ID, &document.Type, &document.Title, &document.Description,
		&document.Status, &document.CreatorID, &document.CreatedAt,
		&document.UpdatedAt, &document.ExpiresAt, &document.TemplateID,
		&document.Version,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
		return
	}

	c.JSON(http.StatusOK, document)
}

func getUserDocuments(c *gin.Context) {
	userID := c.Param("userId")
	var documents []Document

	rows, err := db.Query(context.Background(), `
		SELECT id, type, title, description, status, creator_id,
		       created_at, updated_at, expires_at, template_id, version
		FROM documents.documents
		WHERE creator_id = $1 AND status != 'DELETED'
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve user documents"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var document Document
		err := rows.Scan(
			&document.ID, &document.Type, &document.Title, &document.Description,
			&document.Status, &document.CreatorID, &document.CreatedAt,
			&document.UpdatedAt, &document.ExpiresAt, &document.TemplateID,
			&document.Version,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan document data"})
			return
		}
		documents = append(documents, document)
	}

	c.JSON(http.StatusOK, gin.H{"documents": documents})
}

func createDocument(c *gin.Context) {
	var input struct {
		Type        string `json:"type" binding:"required"`
		Title       string `json:"title" binding:"required"`
		Description string `json:"description"`
		CreatorID   string `json:"creator_id" binding:"required"`
		TemplateID  string `json:"template_id"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if user exists
	var userExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM users.users WHERE id = $1 AND is_active = true)
	`, input.CreatorID).Scan(&userExists)

	if err != nil || !userExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User not found"})
		return
	}

	id := uuid.New().String()

	var templateID *string
	if input.TemplateID != "" {
		templateID = &input.TemplateID
	}

	_, err = db.Exec(context.Background(), `
		INSERT INTO documents.documents (
			id, type, title, description, status, creator_id,
			template_id, version
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8
		)
	`, id, input.Type, input.Title, input.Description, "DRAFT",
		input.CreatorID, templateID, 1)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create document: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Document created successfully",
	})
}

func updateDocument(c *gin.Context) {
	id := c.Param("id")

	var input struct {
		Title       string `json:"title"`
		Description string `json:"description"`
		Status      string `json:"status"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if document exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM documents.documents WHERE id = $1 AND status != 'DELETED')
	`, id).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
		return
	}

	// Update document
	_, err = db.Exec(context.Background(), `
		UPDATE documents.documents
		SET 
			title = COALESCE(NULLIF($1, ''), title),
			description = COALESCE(NULLIF($2, ''), description),
			status = COALESCE(NULLIF($3, ''), status),
			updated_at = $4,
			version = version + 1
		WHERE id = $5 AND status != 'DELETED'
	`, input.Title, input.Description, input.Status, time.Now(), id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update document: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Document updated successfully"})
}

func deleteDocument(c *gin.Context) {
	id := c.Param("id")

	result, err := db.Exec(context.Background(), `
		UPDATE documents.documents
		SET status = 'DELETED', updated_at = $1
		WHERE id = $2 AND status != 'DELETED'
	`, time.Now(), id)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete document: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Document not found"})
		return
	}

	c.Status(http.StatusNoContent)
}

// Files handlers
func getDocumentFiles(c *gin.Context) {
	documentID := c.Param("id")
	var files []File

	rows, err := db.Query(context.Background(), `
		SELECT id, document_id, file_key, file_name, content_type, size_bytes, uploaded_at
		FROM documents.files
		WHERE document_id = $1
	`, documentID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve document files"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var file File
		err := rows.Scan(
			&file.ID, &file.DocumentID, &file.FileKey, &file.FileName,
			&file.ContentType, &file.SizeBytes, &file.UploadedAt,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan file data"})
			return
		}
		files = append(files, file)
	}

	c.JSON(http.StatusOK, gin.H{"files": files})
}

func addDocumentFile(c *gin.Context) {
	documentID := c.Param("id")

	var input struct {
		FileKey     string `json:"file_key" binding:"required"`
		FileName    string `json:"file_name" binding:"required"`
		ContentType string `json:"content_type" binding:"required"`
		SizeBytes   int64  `json:"size_bytes" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if document exists
	var documentExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM documents.documents WHERE id = $1 AND status != 'DELETED')
	`, documentID).Scan(&documentExists)

	if err != nil || !documentExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Document not found"})
		return
	}

	id := uuid.New().String()

	_, err = db.Exec(context.Background(), `
		INSERT INTO documents.files (
			id, document_id, file_key, file_name, content_type, size_bytes, uploaded_at
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
	`, id, documentID, input.FileKey, input.FileName, input.ContentType,
		input.SizeBytes, time.Now())

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add document file: " + err.Error()})
		return
	}

	// Update document version and timestamp
	_, err = db.Exec(context.Background(), `
		UPDATE documents.documents
		SET updated_at = $1, version = version + 1
		WHERE id = $2
	`, time.Now(), documentID)

	if err != nil {
		log.Printf("Warning: Failed to update document version: %v", err)
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "File added successfully",
	})
}

func removeDocumentFile(c *gin.Context) {
	documentID := c.Param("id")
	fileID := c.Param("fileId")

	result, err := db.Exec(context.Background(), `
		DELETE FROM documents.files
		WHERE id = $1 AND document_id = $2
	`, fileID, documentID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove file: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Update document version and timestamp
	_, err = db.Exec(context.Background(), `
		UPDATE documents.documents
		SET updated_at = $1, version = version + 1
		WHERE id = $2
	`, time.Now(), documentID)

	if err != nil {
		log.Printf("Warning: Failed to update document version: %v", err)
	}

	c.Status(http.StatusNoContent)
}

// Signatories handlers
func getDocumentSignatories(c *gin.Context) {
	documentID := c.Param("id")
	var signatories []Signatory

	rows, err := db.Query(context.Background(), `
		SELECT id, document_id, user_id, name, email, role, 
		       signed_at, signature_id, "order", required
		FROM documents.signatories
		WHERE document_id = $1
		ORDER BY "order" ASC
	`, documentID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve signatories"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var signatory Signatory
		err := rows.Scan(
			&signatory.ID, &signatory.DocumentID, &signatory.UserID, &signatory.Name,
			&signatory.Email, &signatory.Role, &signatory.SignedAt, &signatory.SignatureID,
			&signatory.Order, &signatory.Required,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan signatory data"})
			return
		}
		signatories = append(signatories, signatory)
	}

	c.JSON(http.StatusOK, gin.H{"signatories": signatories})
}

func addSignatory(c *gin.Context) {
	documentID := c.Param("id")

	var input struct {
		UserID   string `json:"user_id"`
		Name     string `json:"name" binding:"required"`
		Email    string `json:"email" binding:"required"`
		Role     string `json:"role" binding:"required"`
		Order    int    `json:"order"`
		Required bool   `json:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if document exists
	var documentExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM documents.documents WHERE id = $1 AND status != 'DELETED')
	`, documentID).Scan(&documentExists)

	if err != nil || !documentExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Document not found"})
		return
	}

	id := uuid.New().String()

	// If order not specified, get the next order number
	order := input.Order
	if order == 0 {
		err := db.QueryRow(context.Background(), `
			SELECT COALESCE(MAX("order"), 0) + 1
			FROM documents.signatories
			WHERE document_id = $1
		`, documentID).Scan(&order)

		if err != nil {
			log.Printf("Warning: Failed to get next order number: %v", err)
			order = 1 // Default to 1 if we can't determine the next order
		}
	}

	_, err = db.Exec(context.Background(), `
		INSERT INTO documents.signatories (
			id, document_id, user_id, name, email, role, "order", required
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8
		)
	`, id, documentID, input.UserID, input.Name, input.Email, input.Role,
		order, input.Required)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add signatory: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Signatory added successfully",
	})
}

func updateSignatory(c *gin.Context) {
	documentID := c.Param("id")
	signatoryID := c.Param("signatoryId")

	var input struct {
		Name     string `json:"name"`
		Email    string `json:"email"`
		Role     string `json:"role"`
		Order    int    `json:"order"`
		Required bool   `json:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if signatory exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM documents.signatories WHERE id = $1 AND document_id = $2)
	`, signatoryID, documentID).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Signatory not found"})
		return
	}

	// Update signatory
	_, err = db.Exec(context.Background(), `
		UPDATE documents.signatories
		SET 
			name = COALESCE(NULLIF($1, ''), name),
			email = COALESCE(NULLIF($2, ''), email),
			role = COALESCE(NULLIF($3, ''), role),
			"order" = CASE WHEN $4 > 0 THEN $4 ELSE "order" END,
			required = $5
		WHERE id = $6 AND document_id = $7
	`, input.Name, input.Email, input.Role, input.Order, input.Required,
		signatoryID, documentID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update signatory: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Signatory updated successfully"})
}

func removeSignatory(c *gin.Context) {
	documentID := c.Param("id")
	signatoryID := c.Param("signatoryId")

	result, err := db.Exec(context.Background(), `
		DELETE FROM documents.signatories
		WHERE id = $1 AND document_id = $2
	`, signatoryID, documentID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove signatory: " + err.Error()})
		return
	}

	rowsAffected := result.RowsAffected()
	if rowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Signatory not found"})
		return
	}

	c.Status(http.StatusNoContent)
}

// Signing handlers
func signDocument(c *gin.Context) {
	documentID := c.Param("id")

	var input struct {
		SignatoryID string `json:"signatory_id" binding:"required"`
		UserID      string `json:"user_id" binding:"required"`
		SignatureID string `json:"signature_id"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Verify the signatory exists and is associated with this document
	var signatoryExists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(
			SELECT 1 FROM documents.signatories 
			WHERE id = $1 AND document_id = $2 AND signed_at IS NULL
		)
	`, input.SignatoryID, documentID).Scan(&signatoryExists)

	if err != nil || !signatoryExists {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Signatory not found or already signed"})
		return
	}

	// Record the signature
	now := time.Now()
	_, err = db.Exec(context.Background(), `
		UPDATE documents.signatories
		SET signed_at = $1, signature_id = $2
		WHERE id = $3 AND document_id = $4 AND signed_at IS NULL
	`, now, input.SignatureID, input.SignatoryID, documentID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to sign document: " + err.Error()})
		return
	}

	// Check if all required signatories have signed
	var allSigned bool
	err = db.QueryRow(context.Background(), `
		SELECT NOT EXISTS(
			SELECT 1 FROM documents.signatories
			WHERE document_id = $1 AND required = true AND signed_at IS NULL
		)
	`, documentID).Scan(&allSigned)

	if err != nil {
		log.Printf("Error checking if all signatories have signed: %v", err)
	} else if allSigned {
		// If all required signatories have signed, update the document status
		_, err := db.Exec(context.Background(), `
			UPDATE documents.documents
			SET status = 'SIGNED', updated_at = $1
			WHERE id = $2 AND status = 'PENDING'
		`, now, documentID)

		if err != nil {
			log.Printf("Error updating document status to SIGNED: %v", err)
		}
	}

	c.JSON(http.StatusOK, gin.H{"message": "Document signed successfully"})
}

// Templates handlers
func listTemplates(c *gin.Context) {
	var templates []struct {
		ID          string    `json:"id"`
		Name        string    `json:"name"`
		Description string    `json:"description,omitempty"`
		Type        string    `json:"type"`
		CreatedAt   time.Time `json:"created_at"`
		UpdatedAt   time.Time `json:"updated_at"`
		Version     int       `json:"version"`
		IsActive    bool      `json:"is_active"`
	}

	rows, err := db.Query(context.Background(), `
		SELECT id, name, description, type, created_at, updated_at, version, is_active
		FROM documents.templates
		WHERE is_active = true
		ORDER BY name
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to retrieve templates"})
		return
	}
	defer rows.Close()

	for rows.Next() {
		var template struct {
			ID          string    `json:"id"`
			Name        string    `json:"name"`
			Description string    `json:"description,omitempty"`
			Type        string    `json:"type"`
			CreatedAt   time.Time `json:"created_at"`
			UpdatedAt   time.Time `json:"updated_at"`
			Version     int       `json:"version"`
			IsActive    bool      `json:"is_active"`
		}
		err := rows.Scan(
			&template.ID, &template.Name, &template.Description, &template.Type,
			&template.CreatedAt, &template.UpdatedAt, &template.Version, &template.IsActive,
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to scan template data"})
			return
		}
		templates = append(templates, template)
	}

	c.JSON(http.StatusOK, gin.H{"templates": templates})
}

func getTemplateByID(c *gin.Context) {
	id := c.Param("id")

	var template struct {
		ID          string    `json:"id"`
		Name        string    `json:"name"`
		Description string    `json:"description,omitempty"`
		Type        string    `json:"type"`
		Content     string    `json:"content"`
		Variables   []string  `json:"variables"`
		CreatedAt   time.Time `json:"created_at"`
		UpdatedAt   time.Time `json:"updated_at"`
		Version     int       `json:"version"`
		IsActive    bool      `json:"is_active"`
	}

	err := db.QueryRow(context.Background(), `
		SELECT id, name, description, type, content, variables, 
		       created_at, updated_at, version, is_active
		FROM documents.templates
		WHERE id = $1 AND is_active = true
	`, id).Scan(
		&template.ID, &template.Name, &template.Description, &template.Type,
		&template.Content, &template.Variables, &template.CreatedAt,
		&template.UpdatedAt, &template.Version, &template.IsActive,
	)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Template not found"})
		return
	}

	c.JSON(http.StatusOK, template)
}

func createTemplate(c *gin.Context) {
	var input struct {
		Name        string   `json:"name" binding:"required"`
		Description string   `json:"description"`
		Type        string   `json:"type" binding:"required"`
		Content     string   `json:"content" binding:"required"`
		Variables   []string `json:"variables"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	id := uuid.New().String()

	_, err := db.Exec(context.Background(), `
		INSERT INTO documents.templates (
			id, name, description, type, content, variables, version, is_active
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7, $8
		)
	`, id, input.Name, input.Description, input.Type, input.Content,
		input.Variables, 1, true)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create template: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      id,
		"message": "Template created successfully",
	})
}

func updateTemplate(c *gin.Context) {
	id := c.Param("id")

	var input struct {
		Name        string   `json:"name"`
		Description string   `json:"description"`
		Content     string   `json:"content"`
		Variables   []string `json:"variables"`
		IsActive    *bool    `json:"is_active"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if template exists
	var exists bool
	err := db.QueryRow(context.Background(), `
		SELECT EXISTS(SELECT 1 FROM documents.templates WHERE id = $1)
	`, id).Scan(&exists)

	if err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Template not found"})
		return
	}

	// Update template
	query := `
		UPDATE documents.templates
		SET 
			name = COALESCE(NULLIF($1, ''), name),
			description = COALESCE(NULLIF($2, ''), description),
			content = COALESCE(NULLIF($3, ''), content),
			variables = COALESCE($4, variables),
			updated_at = $5,
			version = version + 1
	`

	args := []interface{}{
		input.Name, input.Description, input.Content,
		input.Variables, time.Now(),
	}

	if input.IsActive != nil {
		query += `, is_active = $6
			WHERE id = $7`
		args = append(args, *input.IsActive, id)
	} else {
		query += `
			WHERE id = $6`
		args = append(args, id)
	}

	_, err = db.Exec(context.Background(), query, args...)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update template: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Template updated successfully"})
}

func generateDocument(c *gin.Context) {
	templateID := c.Param("id")

	var input struct {
		Title     string                 `json:"title" binding:"required"`
		CreatorID string                 `json:"creator_id" binding:"required"`
		Variables map[string]interface{} `json:"variables"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get template
	var template struct {
		ID      string
		Type    string
		Content string
	}

	err := db.QueryRow(context.Background(), `
		SELECT id, type, content
		FROM documents.templates
		WHERE id = $1 AND is_active = true
	`, templateID).Scan(&template.ID, &template.Type, &template.Content)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Template not found"})
		return
	}

	// Create document from template
	documentID := uuid.New().String()

	_, err = db.Exec(context.Background(), `
		INSERT INTO documents.documents (
			id, type, title, status, creator_id, template_id, version
		) VALUES (
			$1, $2, $3, $4, $5, $6, $7
		)
	`, documentID, template.Type, input.Title, "DRAFT",
		input.CreatorID, templateID, 1)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate document: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"id":      documentID,
		"message": "Document generated successfully",
	})
}

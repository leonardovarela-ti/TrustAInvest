package api

import (
"net/http"

"github.com/gin-gonic/gin"
"github.com/google/uuid"
)

// UserHandler handles HTTP requests for user operations
type UserHandler struct {
userService UserService
}

// NewUserHandler creates a new UserHandler
func NewUserHandler(userService UserService) *UserHandler {
return &UserHandler{
userService: userService,
}
}

// UserService defines the user service interface
type UserService interface {
GetUserByID(id string) (*User, error)
CreateUser(user *User) error
UpdateUser(user *User) error
DeleteUser(id string) error
}

// User represents a user entity
type User struct {
ID        string `json:"id"`
Username  string `json:"username"`
Email     string `json:"email"`
FirstName string `json:"first_name"`
LastName  string `json:"last_name"`
}

// RegisterRoutes registers the user API routes
func (h *UserHandler) RegisterRoutes(router *gin.Engine) {
userGroup := router.Group("/api/v1/users")
{
userGroup.GET("/:id", h.GetUser)
userGroup.POST("/", h.CreateUser)
userGroup.PUT("/:id", h.UpdateUser)
userGroup.DELETE("/:id", h.DeleteUser)
}
}

// GetUser godoc
// @Summary Get a user by ID
// @Description Get user details by user ID
// @Tags users
// @Accept json
// @Produce json
// @Param id path string true "User ID"
// @Success 200 {object} User
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users/{id} [get]
func (h *UserHandler) GetUser(c *gin.Context) {
id := c.Param("id")

user, err := h.userService.GetUserByID(id)
if err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

if user == nil {
c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
return
}

c.JSON(http.StatusOK, user)
}

// CreateUser godoc
// @Summary Create a new user
// @Description Create a new user with the provided details
// @Tags users
// @Accept json
// @Produce json
// @Param user body User true "User details"
// @Success 201 {object} User
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users [post]
func (h *UserHandler) CreateUser(c *gin.Context) {
var user User
if err := c.ShouldBindJSON(&user); err != nil {
c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
return
}

// Generate a new UUID for the user
user.ID = uuid.New().String()

if err := h.userService.CreateUser(&user); err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

c.JSON(http.StatusCreated, user)
}

// UpdateUser godoc
// @Summary Update a user
// @Description Update an existing user's details
// @Tags users
// @Accept json
// @Produce json
// @Param id path string true "User ID"
// @Param user body User true "User details"
// @Success 200 {object} User
// @Failure 400 {object} ErrorResponse
// @Failure 404 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users/{id} [put]
func (h *UserHandler) UpdateUser(c *gin.Context) {
id := c.Param("id")

var user User
if err := c.ShouldBindJSON(&user); err != nil {
c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
return
}

user.ID = id

if err := h.userService.UpdateUser(&user); err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

c.JSON(http.StatusOK, user)
}

// DeleteUser godoc
// @Summary Delete a user
// @Description Delete a user by ID
// @Tags users
// @Accept json
// @Produce json
// @Param id path string true "User ID"
// @Success 204 "No Content"
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users/{id} [delete]
func (h *UserHandler) DeleteUser(c *gin.Context) {
id := c.Param("id")

if err := h.userService.DeleteUser(id); err != nil {
c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
return
}

c.Status(http.StatusNoContent)
}

// ErrorResponse represents an error response
type ErrorResponse struct {
Error string `json:"error"`
}

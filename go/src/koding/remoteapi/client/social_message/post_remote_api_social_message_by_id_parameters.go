package social_message

// This file was generated by the swagger tool.
// Editing this file might prove futile when you re-run the swagger generate command

import (
	"net/http"
	"time"

	"golang.org/x/net/context"

	"github.com/go-openapi/errors"
	"github.com/go-openapi/runtime"
	cr "github.com/go-openapi/runtime/client"

	strfmt "github.com/go-openapi/strfmt"

	"koding/remoteapi/models"
)

// NewPostRemoteAPISocialMessageByIDParams creates a new PostRemoteAPISocialMessageByIDParams object
// with the default values initialized.
func NewPostRemoteAPISocialMessageByIDParams() *PostRemoteAPISocialMessageByIDParams {
	var ()
	return &PostRemoteAPISocialMessageByIDParams{

		timeout: cr.DefaultTimeout,
	}
}

// NewPostRemoteAPISocialMessageByIDParamsWithTimeout creates a new PostRemoteAPISocialMessageByIDParams object
// with the default values initialized, and the ability to set a timeout on a request
func NewPostRemoteAPISocialMessageByIDParamsWithTimeout(timeout time.Duration) *PostRemoteAPISocialMessageByIDParams {
	var ()
	return &PostRemoteAPISocialMessageByIDParams{

		timeout: timeout,
	}
}

// NewPostRemoteAPISocialMessageByIDParamsWithContext creates a new PostRemoteAPISocialMessageByIDParams object
// with the default values initialized, and the ability to set a context for a request
func NewPostRemoteAPISocialMessageByIDParamsWithContext(ctx context.Context) *PostRemoteAPISocialMessageByIDParams {
	var ()
	return &PostRemoteAPISocialMessageByIDParams{

		Context: ctx,
	}
}

/*PostRemoteAPISocialMessageByIDParams contains all the parameters to send to the API endpoint
for the post remote API social message by ID operation typically these are written to a http.Request
*/
type PostRemoteAPISocialMessageByIDParams struct {

	/*Body
	  body of the request

	*/
	Body models.DefaultSelector

	timeout    time.Duration
	Context    context.Context
	HTTPClient *http.Client
}

// WithTimeout adds the timeout to the post remote API social message by ID params
func (o *PostRemoteAPISocialMessageByIDParams) WithTimeout(timeout time.Duration) *PostRemoteAPISocialMessageByIDParams {
	o.SetTimeout(timeout)
	return o
}

// SetTimeout adds the timeout to the post remote API social message by ID params
func (o *PostRemoteAPISocialMessageByIDParams) SetTimeout(timeout time.Duration) {
	o.timeout = timeout
}

// WithContext adds the context to the post remote API social message by ID params
func (o *PostRemoteAPISocialMessageByIDParams) WithContext(ctx context.Context) *PostRemoteAPISocialMessageByIDParams {
	o.SetContext(ctx)
	return o
}

// SetContext adds the context to the post remote API social message by ID params
func (o *PostRemoteAPISocialMessageByIDParams) SetContext(ctx context.Context) {
	o.Context = ctx
}

// WithBody adds the body to the post remote API social message by ID params
func (o *PostRemoteAPISocialMessageByIDParams) WithBody(body models.DefaultSelector) *PostRemoteAPISocialMessageByIDParams {
	o.SetBody(body)
	return o
}

// SetBody adds the body to the post remote API social message by ID params
func (o *PostRemoteAPISocialMessageByIDParams) SetBody(body models.DefaultSelector) {
	o.Body = body
}

// WriteToRequest writes these params to a swagger request
func (o *PostRemoteAPISocialMessageByIDParams) WriteToRequest(r runtime.ClientRequest, reg strfmt.Registry) error {

	r.SetTimeout(o.timeout)
	var res []error

	if err := r.SetBodyParam(o.Body); err != nil {
		return err
	}

	if len(res) > 0 {
		return errors.CompositeValidationError(res...)
	}
	return nil
}

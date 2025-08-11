// Copyright 2024 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.

package routing

import (
	"encoding/json"
	"net/http"

	"github.com/element-hq/dendrite/clientapi/auth"
	"github.com/element-hq/dendrite/setup/config"
	userapi "github.com/element-hq/dendrite/userapi/api"
	"github.com/matrix-org/gomatrixserverlib/spec"
	"github.com/matrix-org/util"
)

type refreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}

type refreshResponse struct {
	AccessToken  string  `json:"access_token"`
	RefreshToken *string `json:"refresh_token,omitempty"`
	ExpiresInMs  *int64  `json:"expires_in_ms,omitempty"`
}

func Refresh(
	req *http.Request, userAPI userapi.ClientUserAPI,
	cfg *config.ClientAPI,
) util.JSONResponse {
	if req.Method != http.MethodPost {
		return util.JSONResponse{
			Code: http.StatusMethodNotAllowed,
			JSON: spec.NotFound("Bad method"),
		}
	}

	var refreshReq refreshRequest
	if err := json.NewDecoder(req.Body).Decode(&refreshReq); err != nil {
		return util.JSONResponse{
			Code: http.StatusBadRequest,
			JSON: spec.BadJSON("Invalid JSON"),
		}
	}

	if refreshReq.RefreshToken == "" {
		return util.JSONResponse{
			Code: http.StatusBadRequest,
			JSON: spec.MissingParam("refresh_token is required"),
		}
	}

	var queryRes userapi.QueryRefreshTokenResponse
	err := userAPI.QueryRefreshToken(req.Context(), &userapi.QueryRefreshTokenRequest{
		RefreshToken: refreshReq.RefreshToken,
	}, &queryRes)
	if err != nil {
		util.GetLogger(req.Context()).WithError(err).Error("userAPI.QueryRefreshToken failed")
		return util.JSONResponse{
			Code: http.StatusInternalServerError,
			JSON: spec.InternalServerError{},
		}
	}

	if queryRes.Device == nil {
		return util.JSONResponse{
			Code: http.StatusForbidden,
			JSON: spec.Forbidden("Invalid refresh token"),
		}
	}

	newAccessToken, err := auth.GenerateAccessToken()
	if err != nil {
		util.GetLogger(req.Context()).WithError(err).Error("auth.GenerateAccessToken failed")
		return util.JSONResponse{
			Code: http.StatusInternalServerError,
			JSON: spec.InternalServerError{},
		}
	}

	newRefreshToken, err := auth.GenerateAccessToken()
	if err != nil {
		util.GetLogger(req.Context()).WithError(err).Error("auth.GenerateAccessToken failed for refresh token")
		return util.JSONResponse{
			Code: http.StatusInternalServerError,
			JSON: spec.InternalServerError{},
		}
	}

	var updateRes userapi.PerformRefreshTokenUpdateResponse
	err = userAPI.PerformRefreshTokenUpdate(req.Context(), &userapi.PerformRefreshTokenUpdateRequest{
		DeviceID:        queryRes.Device.ID,
		UserID:          queryRes.Device.UserID,
		OldRefreshToken: refreshReq.RefreshToken,
		NewAccessToken:  newAccessToken,
		NewRefreshToken: newRefreshToken,
	}, &updateRes)
	if err != nil {
		util.GetLogger(req.Context()).WithError(err).Error("userAPI.PerformRefreshTokenUpdate failed")
		return util.JSONResponse{
			Code: http.StatusInternalServerError,
			JSON: spec.InternalServerError{},
		}
	}

	return util.JSONResponse{
		Code: http.StatusOK,
		JSON: refreshResponse{
			AccessToken:  newAccessToken,
			RefreshToken: &newRefreshToken,
		},
	}
}

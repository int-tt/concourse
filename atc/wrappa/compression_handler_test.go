package wrappa_test

import (
	"net/http"
	"net/http/httptest"

	"github.com/concourse/concourse/atc/wrappa"
	"github.com/concourse/concourse/atc/wrappa/wrappafakes"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("CompressionHandler", func() {
	var (
		request *http.Request
		rw      *httptest.ResponseRecorder

		fakeHandler *wrappafakes.FakeHandler

		compressionHandler wrappa.CompressionHandler
	)

	BeforeEach(func() {
		rw = httptest.NewRecorder()
		request = httptest.NewRequest("GET", "/some/path", nil)

		fakeHandler = new(wrappafakes.FakeHandler)

		compressionHandler = wrappa.CompressionHandler{
			Handler: fakeHandler,
		}
	})

	JustBeforeEach(func() {
		compressionHandler.ServeHTTP(rw, request)
	})

	It("sets the vary header", func() {
		Expect(rw.Header().Get("Vary")).To(Equal("Accept-Encoding"))
	})

	Context("when request header has no Accept-Encoding gzip", func() {
		It("dosen't set the encoding header", func() {
			Expect(rw.Header().Get("Content-Encoding")).To(Equal(""))
		})

		It("serves the HTTP request", func() {
			Expect(fakeHandler.ServeHTTPCallCount()).To(Equal(1))
		})
	})

	Context("when request header has Accept-Encoding gzip", func() {
		BeforeEach(func() {
			request.Header.Set("Accept-Encoding", "gzip")
		})

		It("sets the correct headers", func() {
			Expect(rw.Header().Get("Content-Encoding")).To(Equal("gzip"))
		})

		It("serves the HTTP request", func() {
			Expect(fakeHandler.ServeHTTPCallCount()).To(Equal(1))
		})

		Context("when there are multiple responses need to be gzip", func() {
			BeforeEach(func() {
				request2 := httptest.NewRequest("PUT", "/some/other-path", nil)
				request2.Header.Set("Accept-Encoding", "gzip")

				compressionHandler.ServeHTTP(rw, request2)
			})

			It("reuse gzip writer", func() {
				Expect(fakeHandler.ServeHTTPCallCount()).To(Equal(2))

				gzRW1, _ := fakeHandler.ServeHTTPArgsForCall(0)
				gzRW2, _ := fakeHandler.ServeHTTPArgsForCall(1)

				Expect(gzRW1).To(Equal(gzRW2))
			})
		})
	})

})

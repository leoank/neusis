package doctor

// Status represents the severity of a doctor check result.
type Status string

const (
	StatusPass Status = "PASS"
	StatusInfo Status = "INFO"
	StatusWarn Status = "WARN"
	StatusFail Status = "FAIL"
)

// Item is a single diagnostic observation.
type Item struct {
	Status  Status `json:"status"`
	Title   string `json:"title"`
	Message string `json:"message,omitempty"`
	File    string `json:"file,omitempty"`
	Remedy  string `json:"remedy,omitempty"`
}

// Category groups related diagnostic checks.
type Category struct {
	Name  string `json:"name"`
	Items []Item `json:"items"`
}

// Report holds the full diagnostic results for a fleet repository.
type Report struct {
	RepoRoot   string     `json:"repoRoot"`
	Categories []Category `json:"categories"`
	PassCount  int        `json:"passCount"`
	InfoCount  int        `json:"infoCount"`
	WarnCount  int        `json:"warnCount"`
	FailCount  int        `json:"failCount"`
}

// OK reports whether the report has no failures.
func (r *Report) OK() bool {
	return r.FailCount == 0
}

// StrictOK reports whether the report has no failures and no warnings.
func (r *Report) StrictOK() bool {
	return r.FailCount == 0 && r.WarnCount == 0
}

// AddItem records an item into the specified category and updates counters.
func (r *Report) AddItem(categoryName string, item Item) {
	switch item.Status {
	case StatusPass:
		r.PassCount++
	case StatusInfo:
		r.InfoCount++
	case StatusWarn:
		r.WarnCount++
	case StatusFail:
		r.FailCount++
	}

	for i := range r.Categories {
		if r.Categories[i].Name == categoryName {
			r.Categories[i].Items = append(r.Categories[i].Items, item)
			return
		}
	}
	r.Categories = append(r.Categories, Category{
		Name:  categoryName,
		Items: []Item{item},
	})
}

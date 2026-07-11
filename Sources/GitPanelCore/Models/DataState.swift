import Foundation

public enum DataState<T> {
    case idle
    case loading
    case loaded(T)
    case failed(Error)
    
    public var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }
    
    public var error: Error? {
        if case .failed(let e) = self { return e }
        return nil
    }
    
    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

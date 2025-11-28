import React from "react";
import { Button, Modal } from "react-bootstrap";
export  const OpenedCourses_ResultModal=React.memo(({modal, handleClose})=>{
          const successCourses=new Set();
          const failedCourses=new Map();
          modal.data.forEach((value,key)=>{
                    if(value==="Enroll successfully") successCourses.add(key)
                    else failedCourses.set(key,value);
          })
        return (
          <Modal show={modal.show} onHide={handleClose}>
            <Modal.Header closeButton>
                <Modal.Title>KẾT QUẢ ĐĂNG KÍ</Modal.Title>
            </Modal.Header>
            <Modal.Body>
                <h6><i className="bi bi-check-circle"></i> {successCourses.size} lớp thành công</h6>
                {Array.from(successCourses).map((value, index) => (
                      <div key={index}>{value}: đăng kí thành công</div>
                  ))}
                 <h6><i className="bi bi-x-circle"></i> {failedCourses.size} lớp bị lỗi</h6>
                {Array.from(failedCourses.entries()).map(([key, value]) => (
                      <div key={key}>{key}: {value}</div>
                  ))}
            </Modal.Body>
          <Modal.Footer>
            <Button variant="danger" onClick={handleClose}>
              Close
            </Button>
          </Modal.Footer>
        </Modal>
      )})
 export const RegisteredCourses_AlertModal=React.memo(({modal, courseData, checkedIds, sendRequest,handleClose})=>{
          const DeletedCourseNames=[]
          for(let c of courseData){
                    if(checkedIds.has(c.id)) DeletedCourseNames.push(c.courseId)
          }
          return(
          <Modal show={modal.show==1} onHide={handleClose}>
                    <Modal.Header closeButton>
                              <Modal.Title>Hủy học phần</Modal.Title>
                    </Modal.Header>
                    <Modal.Body>Bạn có chắc muốn hủy đăng kí các học phần: {DeletedCourseNames.map(name=>name+", ")}
                    </Modal.Body>
                    <Modal.Footer>
                              <Button variant="warning" onClick={handleClose}>
                              Cancel
                              </Button>
                              <Button variant="danger" onClick={sendRequest}>
                                        Delete
                              </Button>
                    </Modal.Footer>
          </Modal>
          )
})
export const RegisteredCourses_ResultModal=React.memo(({modal, handleClose})=>{
          const successCourses=new Set();
          const failedCourses=new Map();
          modal.data.forEach((value,key)=>{
                    if(value==="Unenroll successfully") successCourses.add(key)
                    else failedCourses.set(key,value);
          })
          return(
          <Modal show={modal.show==2} onHide={handleClose}>
                    <Modal.Header closeButton>
                              <Modal.Title>KẾT QUẢ HỦY ĐĂNG KÍ</Modal.Title>
                    </Modal.Header>
                    <Modal.Body>
                              <h6><i className="bi bi-check-circle"></i> {successCourses.size} lớp hủy thành công</h6>
                              {Array.from(successCourses).map((value, index) => (
                              <div key={index}>{value}: hủy thành công</div>
                              ))}
                              <h6><i className="bi bi-x-circle"></i> {failedCourses.size} lớp hủy bị lỗi</h6>
                              {Array.from(failedCourses.entries()).map(([key, value]) => (
                              <div key={key}>{key}: {value}</div>
                              ))}
                    </Modal.Body>
                    <Modal.Footer>
                    <Button variant="danger" onClick={handleClose}>
                              Close
                    </Button>
                    </Modal.Footer>
          </Modal>
          )
})